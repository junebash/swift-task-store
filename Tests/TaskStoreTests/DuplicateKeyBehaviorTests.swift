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

  @Test
  func `wait behavior properties`() {
    let behavior = TaskStoreDuplicateKeyBehavior.wait
    #expect(!behavior.preferPrevious)
    #expect(!behavior.cancelPrevious)
    #expect(behavior.waitForPrevious)
    #expect(behavior.runNewTask)
  }

  @Test
  func `cancelPrevious(wait: false) behavior properties`() {
    let behavior = TaskStoreDuplicateKeyBehavior.cancelPrevious(wait: false)
    #expect(!behavior.preferPrevious)
    #expect(behavior.cancelPrevious)
    #expect(!behavior.waitForPrevious)
    #expect(behavior.runNewTask)
  }

  @Test
  func `cancelPrevious(wait: true) behavior properties`() {
    let behavior = TaskStoreDuplicateKeyBehavior.cancelPrevious(wait: true)
    #expect(!behavior.preferPrevious)
    #expect(behavior.cancelPrevious)
    #expect(behavior.waitForPrevious)
    #expect(behavior.runNewTask)
  }

  @Test
  func `runConcurrently behavior properties`() {
    let behavior = TaskStoreDuplicateKeyBehavior.runConcurrently
    #expect(!behavior.preferPrevious)
    #expect(!behavior.cancelPrevious)
    #expect(!behavior.waitForPrevious)
    #expect(behavior.runNewTask)
  }

  @Test
  func `preferPrevious behavior properties`() {
    let behavior = TaskStoreDuplicateKeyBehavior.preferPrevious
    #expect(behavior.preferPrevious)
    #expect(!behavior.cancelPrevious)
    #expect(behavior.waitForPrevious)  // Default when preferPrevious
    #expect(!behavior.runNewTask)
  }
}
