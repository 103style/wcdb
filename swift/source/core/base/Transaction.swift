/*
 * Tencent is pleased to support the open source community by making
 * WCDB available.
 *
 * Copyright (C) 2017 THL A29 Limited, a Tencent company.
 * All rights reserved.
 *
 * Licensed under the BSD 3-Clause License (the "License"); you may not use
 * this file except in compliance with the License. You may obtain a copy of
 * the License at
 *
 *       https://opensource.org/licenses/BSD-3-Clause
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation
public final class Transaction {
    private let recyclableHandlePool: RecyclableHandlePool
    private let recyclableHandle: RecyclableHandle
    public private(set) var isInTransaction: Bool = false
    private var mutex: RecursiveMutex = RecursiveMutex()

    init(with recyclableHandlePool: RecyclableHandlePool, and recyclableHandle: RecyclableHandle) {
        self.recyclableHandlePool = recyclableHandlePool
        self.recyclableHandle = recyclableHandle
    }

    deinit {
        if isInTransaction {
            try? rollback()
        }
    }

    private var handle: Handle {
        return recyclableHandle.raw.handle
    }

    private var handlePool: HandlePool {
        return recyclableHandlePool.raw
    }

    public var changes: Int {
        mutex.lock(); defer { mutex.unlock() }
        return handle.changes
    }
}

extension Transaction: Core {
    public var path: String {
        return handlePool.path
    }

    public var tag: Tag? {
        get {
            return handlePool.tag
        }
        set {
            handlePool.tag = newValue
        }
    }

    public func prepare(_ statement: Statement) throws -> CoreStatement {
        mutex.lock(); defer { mutex.unlock() }
        guard statement.statementType != .transaction else {
            throw Error.reportCore(tag: tag,
                                   path: path,
                                   operation: .prepare,
                                   code: .misuse,
                                   message: "Using [begin], [commit], [rollback] method to do a transaction")
        }
        let handleStatement = try handle.prepare(statement)
        let recyclableHandleStatement = RecyclableHandleStatement(recyclableHandle: recyclableHandle,
                                                                  handleStatement: handleStatement)
        return CoreStatement(with: self, and: recyclableHandleStatement)
    }

    public func exec(_ statement: Statement) throws {
        mutex.lock(); defer { mutex.unlock() }
        guard statement.statementType != .transaction else {
            throw Error.reportCore(tag: tag,
                                   path: path,
                                   operation: .prepare,
                                   code: .misuse,
                                   message: "Using [begin], [commit], [rollback] method to do a transaction")
        }
        try handle.exec(statement)
    }

    public func isTableExists(_ table: String) throws -> Bool {
        mutex.lock(); defer { mutex.unlock() }
        let select = StatementSelect().select(1).from(table).limit(0)
        Error.threadedSlient.value = true
        let handleStatement = try? handle.prepare(select)
        Error.threadedSlient.value = false
        guard handleStatement != nil else {
            return false
        }
        try handleStatement!.step()
        return true

    }

    public func begin() throws {
        try begin(.immediate)
    }

    func begin(_ mode: StatementTransaction.Mode) throws {
        mutex.lock(); defer { mutex.unlock() }
        try handle.exec(mode == .immediate ?
            CommonStatement.beginTransactionImmediate :
            StatementTransaction().begin(mode))
        isInTransaction = true
    }

    public func commit() throws {
        mutex.lock(); defer { mutex.unlock() }
        try handle.exec(CommonStatement.commitTransaction)
        isInTransaction = false
    }

    public func rollback() throws {
        mutex.lock(); defer { mutex.unlock() }
        try handle.exec(CommonStatement.rollbackTransaction)
        isInTransaction = false
    }

    public func run(transaction: TransactionClosure) throws {
        mutex.lock(); defer { mutex.unlock() }
        try begin()
        do {
            try transaction()
            try commit()
        } catch let error {
            try rollback()
            throw error
        }
    }

    public func run(controlableTransaction: ControlableTransactionClosure) throws {
        mutex.lock(); defer { mutex.unlock() }
        try begin()
        do {
            if try controlableTransaction() {
                try commit()
            } else {
                try rollback()
            }
        } catch let error {
            if isInTransaction {
                try rollback()
            }
            throw error
        }
    }

    public func run(embeddedTransaction: TransactionClosure) throws {
        mutex.lock(); defer { mutex.unlock() }
        if isInTransaction {
            try embeddedTransaction()
        } else {
            try run(transaction: embeddedTransaction)
        }
    }

}

extension Transaction: InsertChainCallInterface {}
extension Transaction: UpdateChainCallInterface {}
extension Transaction: DeleteChainCallInterface {}
extension Transaction: RowSelectChainCallInterface {}
extension Transaction: SelectChainCallInterface {}
extension Transaction: MultiSelectChainCallInterface {}

extension Transaction: InsertInterface {}
extension Transaction: UpdateInterface {}
extension Transaction: DeleteInterface {}
extension Transaction: RowSelectInterface {}
extension Transaction: SelectInterface {}
extension Transaction: TableInterface {}
