//===----------------------------------------------------------------------===//
//
// This source file is part of the swift-task-store open source project
//
// Copyright (c) June Bash
//
// See LICENSE for license information
//
//===----------------------------------------------------------------------===//

import Testing
@testable import TaskStore

@Suite("TaskStoreDuplicateKeyBehavior Tests")
struct TaskStoreDuplicateKeyBehaviorTests {

  @Test("wait behavior properties")
  func waitBehaviorProperties() {
    let behavior = TaskStoreDuplicateKeyBehavior.wait
    #expect(!behavior.preferPrevious)
    #expect(!behavior.cancelPrevious)
    #expect(behavior.waitForPrevious)
    #expect(behavior.runNewTask)
  }

  @Test("cancelPrevious(wait: false) behavior properties")
  func cancelPreviousNoWaitProperties() {
    let behavior = TaskStoreDuplicateKeyBehavior.cancelPrevious(wait: false)
    #expect(!behavior.preferPrevious)
    #expect(behavior.cancelPrevious)
    #expect(!behavior.waitForPrevious)
    #expect(behavior.runNewTask)
  }

  @Test("cancelPrevious(wait: true) behavior properties")
  func cancelPreviousWithWaitProperties() {
    let behavior = TaskStoreDuplicateKeyBehavior.cancelPrevious(wait: true)
    #expect(!behavior.preferPrevious)
    #expect(behavior.cancelPrevious)
    #expect(behavior.waitForPrevious)
    #expect(behavior.runNewTask)
  }

  @Test("runConcurrently behavior properties")
  func runConcurrentlyProperties() {
    let behavior = TaskStoreDuplicateKeyBehavior.runConcurrently
    #expect(!behavior.preferPrevious)
    #expect(!behavior.cancelPrevious)
    #expect(!behavior.waitForPrevious)
    #expect(behavior.runNewTask)
  }

  @Test("preferPrevious behavior properties")
  func preferPreviousProperties() {
    let behavior = TaskStoreDuplicateKeyBehavior.preferPrevious
    #expect(behavior.preferPrevious)
    #expect(!behavior.cancelPrevious)
    #expect(behavior.waitForPrevious)  // Default when preferPrevious
    #expect(!behavior.runNewTask)
  }

  @Test("Behaviors are equatable")
  func behaviorsAreEquatable() {
    #expect(TaskStoreDuplicateKeyBehavior.wait == TaskStoreDuplicateKeyBehavior.wait)
    #expect(
      TaskStoreDuplicateKeyBehavior.cancelPrevious(wait: true)
      == TaskStoreDuplicateKeyBehavior.cancelPrevious(wait: true)
    )
    #expect(
      TaskStoreDuplicateKeyBehavior.cancelPrevious(wait: false)
      != TaskStoreDuplicateKeyBehavior.cancelPrevious(wait: true)
    )
    #expect(
      TaskStoreDuplicateKeyBehavior.runConcurrently
      == TaskStoreDuplicateKeyBehavior.runConcurrently
    )
    #expect(
      TaskStoreDuplicateKeyBehavior.preferPrevious
      == TaskStoreDuplicateKeyBehavior.preferPrevious
    )
  }
}
