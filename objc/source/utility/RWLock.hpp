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

#ifndef RWLock_hpp
#define RWLock_hpp

#include <condition_variable>
#include <mutex>

//TODO std::shared_mutex is supported from C++17

namespace WCDB {

class RWLock {
public:
    RWLock();
    void lockRead();
    void unlockRead();

    void lockWrite();
    void unlockWrite();

    bool isWriting() const;

protected:
    mutable std::mutex m_mutex;
    std::condition_variable m_cond;
    int m_reader;
    int m_writer;
    int m_pending;
};

} //namespace WCDB

#endif /* RWLock_hpp */
