//===----------------------------------------------------------------------===//
//
// This source file is part of the swift-task-store open source project
//
// Copyright (c) June Bash
//
// See LICENSE for license information
//
//===----------------------------------------------------------------------===//

struct TaskData: Sendable {
  var id: UInt64
  var task: Task<Void, Never>
}
