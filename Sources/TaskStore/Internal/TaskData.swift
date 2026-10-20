//===----------------------------------------------------------------------===//
//
// This source file is part of the swift-task-store open source project
//
// Copyright (c) June Bash
//
// See LICENSE for license information
//
//===----------------------------------------------------------------------===//

@usableFromInline
struct TaskData: Sendable, Equatable {
  @usableFromInline
  var id: UInt64

  @usableFromInline
  var task: Task<Void, Never>

  @inlinable
  init(id: UInt64, task: Task<Void, Never>) {
    self.id = id
    self.task = task
  }
}
