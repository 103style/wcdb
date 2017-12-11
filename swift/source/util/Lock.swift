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

class Lock {
    func lock() {
        Error.abort("")
    }

    func unlock() {
        Error.abort("")
    }
}

class UnfairLock: Lock {
    var unfairLock = os_unfair_lock_s()

    override func lock() {
        guard #available(iOS 10.0, macOS 10.12, *) else {
            Error.abort("")
        }
        os_unfair_lock_lock(&unfairLock)
    }

    override func unlock() {
        guard #available(iOS 10.0, macOS 10.12, *) else {
            Error.abort("")
        }
        os_unfair_lock_unlock(&unfairLock)
    }
}

class Mutex: Lock {
    var mutex = pthread_mutex_t()

    override init() {
        pthread_mutex_init(&mutex, nil)
    }

    deinit {
        pthread_mutex_destroy(&mutex)
    }

    override func lock() {
        pthread_mutex_lock(&mutex)
    }

    override func unlock() {
        pthread_mutex_unlock(&mutex)
    }
}

class RecursiveMutex: Lock {
    var mutex = pthread_mutex_t()

    override init() {
        var attr = pthread_mutexattr_t()
        pthread_mutexattr_init(&attr)
        pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE)
        pthread_mutex_init(&mutex, &attr)
    }

    deinit {
        pthread_mutex_destroy(&mutex)
    }

    override func lock() {
        pthread_mutex_lock(&mutex)
    }

    override func unlock() {
        pthread_mutex_unlock(&mutex)
    }
}

class Spin: Lock {
    let unfair: UnfairLock?
    let mutex: Mutex?

    override init() {
        if #available(iOS 10.0, macOS 10.12, *) {
            mutex = nil
            unfair = UnfairLock()
        } else {
            mutex = Mutex()
            unfair = nil
        }
    }

    override func lock() {
        if #available(iOS 10.0, macOS 10.12, *) {
            unfair!.lock()
        } else {
            mutex!.lock()
        }
    }

    override func unlock() {
        if #available(iOS 10.0, macOS 10.12, *) {
            unfair!.unlock()
        } else {
            mutex!.unlock()
        }
    }
}

class ConditionLock: Lock {
    var mutex = pthread_mutex_t()
    var cond = pthread_cond_t()

    override init() {
        pthread_mutex_init(&mutex, nil)
        pthread_cond_init(&cond, nil)
    }

    deinit {
        pthread_cond_destroy(&cond)
        pthread_mutex_destroy(&mutex)
    }

    override func lock() {
        pthread_mutex_lock(&mutex)
    }

    override func unlock() {
        pthread_mutex_unlock(&mutex)
    }

    func wait() {
        pthread_cond_wait(&cond, &mutex)
    }

    func signal() {
        pthread_cond_signal(&cond)
    }

    func broadcast() {
        pthread_cond_broadcast(&cond)
    }
}
