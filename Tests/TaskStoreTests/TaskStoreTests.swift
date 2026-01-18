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
import Foundation
import Observation
@testable import TaskStore

@Suite("TaskStore Tests")
struct TaskStoreTests {

  enum TestKey: Hashable, Sendable {
    case first
    case second
    case third
  }

  // MARK: - Basic Functionality

  @Test("Task runs and completes")
  func taskRunsAndCompletes() async {
    let store = TaskStore<TestKey>()

    await confirmation { didRun in
      let task = store.addTask(forKey: .first) {
        didRun()
      }
      await task.value
    }

    #expect(!store.taskIsRunning(forKey: .first))
  }

  @Test("taskIsRunning returns true while task is active")
  func taskIsRunningWhileActive() async {
    let store = TaskStore<TestKey>()
    let started = AsyncStream.makeStream(of: Void.self)
    let canFinish = AsyncStream.makeStream(of: Void.self)

    let task = store.addTask(forKey: .first) {
      started.continuation.yield()
      for await _ in canFinish.stream { break }
    }

    for await _ in started.stream { break }
    #expect(store.taskIsRunning(forKey: .first))

    canFinish.continuation.yield()
    canFinish.continuation.finish()

    await task.value
    #expect(!store.taskIsRunning(forKey: .first))
  }

  @Test("taskIsRunning returns false for unknown key")
  func taskIsRunningFalseForUnknownKey() {
    let store = TaskStore<TestKey>()
    #expect(!store.taskIsRunning(forKey: .first))
  }

  @Test("cancelTask cancels running task")
  func cancelTaskCancelsRunning() async {
    let store = TaskStore<TestKey>()
    let started = AsyncStream.makeStream(of: Void.self)
    let cancelled = AsyncStream.makeStream(of: Bool.self)
    let neverFinishes = AsyncStream<Void>.makeStream()

    store.addTask(forKey: .first) {
      started.continuation.yield()
      for await _ in neverFinishes.stream { break }
      cancelled.continuation.yield(Task.isCancelled)
      cancelled.continuation.finish()
    }

    for await _ in started.stream { break }
    store.cancelTask(forKey: .first)
    neverFinishes.continuation.finish()

    for await wasCancelled in cancelled.stream {
      #expect(wasCancelled)
      break
    }
  }

  @Test("cancelTask does nothing for unknown key")
  func cancelTaskNoOpForUnknownKey() {
    let store = TaskStore<TestKey>()
    // Should not throw or crash
    store.cancelTask(forKey: .first)
  }

  // MARK: - Multiple Tasks

  @Test("Multiple tasks with different keys run concurrently")
  func multipleTasksDifferentKeys() async {
    let store = TaskStore<TestKey>()
    let firstStarted = AsyncStream.makeStream(of: Void.self)
    let secondStarted = AsyncStream.makeStream(of: Void.self)
    let canFinish = AsyncStream.makeStream(of: Void.self)

    store.addTask(forKey: .first) {
      firstStarted.continuation.yield()
      for await _ in canFinish.stream { break }
    }

    store.addTask(forKey: .second) {
      secondStarted.continuation.yield()
      for await _ in canFinish.stream { break }
    }

    // Wait for both tasks to start
    for await _ in firstStarted.stream { break }
    for await _ in secondStarted.stream { break }

    #expect(store.taskIsRunning(forKey: .first))
    #expect(store.taskIsRunning(forKey: .second))
    #expect(store.runningTaskCount == 2)
    #expect(store.runningTaskKeys == [.first, .second])

    canFinish.continuation.finish()
  }

  @Test("cancelAllTasks cancels all running tasks")
  func cancelAllTasksCancelsAll() async {
    let store = TaskStore<TestKey>()
    let firstStarted = AsyncStream.makeStream(of: Void.self)
    let secondStarted = AsyncStream.makeStream(of: Void.self)
    let firstCancelled = AsyncStream.makeStream(of: Bool.self)
    let secondCancelled = AsyncStream.makeStream(of: Bool.self)
    let neverFinishes = AsyncStream<Void>.makeStream()

    store.addTask(forKey: .first) {
      firstStarted.continuation.yield()
      for await _ in neverFinishes.stream { break }
      firstCancelled.continuation.yield(Task.isCancelled)
      firstCancelled.continuation.finish()
    }

    store.addTask(forKey: .second) {
      secondStarted.continuation.yield()
      for await _ in neverFinishes.stream { break }
      secondCancelled.continuation.yield(Task.isCancelled)
      secondCancelled.continuation.finish()
    }

    // Wait for both tasks to start
    for await _ in firstStarted.stream { break }
    for await _ in secondStarted.stream { break }

    store.cancelAllTasks()
    neverFinishes.continuation.finish()

    for await wasCancelled in firstCancelled.stream {
      #expect(wasCancelled)
      break
    }
    for await wasCancelled in secondCancelled.stream {
      #expect(wasCancelled)
      break
    }
  }

  // MARK: - Duplicate Key Behaviors

  @Test("cancelPrevious(wait: false) cancels previous and runs new immediately")
  func cancelPreviousNoWait() async throws {
    let store = TaskStore<TestKey>()
    let firstStarted = AsyncStream.makeStream(of: Void.self)
    let firstCancelled = AsyncStream.makeStream(of: Bool.self)
    let neverFinishes = AsyncStream<Void>.makeStream()

    await confirmation(expectedCount: 2) { taskRan in
      store.addTask(forKey: .first, duplicateKeyBehavior: .cancelPrevious(wait: false)) {
        taskRan()
        firstStarted.continuation.yield()
        for await _ in neverFinishes.stream { break }
        firstCancelled.continuation.yield(Task.isCancelled)
        firstCancelled.continuation.finish()
      }

      for await _ in firstStarted.stream { break }

      let secondTask = store.addTask(
        forKey: .first,
        duplicateKeyBehavior: .cancelPrevious(wait: false)
      ) {
        taskRan()
      }

      neverFinishes.continuation.finish()
      await secondTask.value
    }

    for await wasCancelled in firstCancelled.stream {
      #expect(wasCancelled)
      break
    }
  }

  @Test("cancelPrevious(wait: true) cancels previous and waits before running new")
  func cancelPreviousWithWait() async throws {
    let store = TaskStore<TestKey>()
    let tracker = OrderTracker()
    let firstStarted = AsyncStream.makeStream(of: Void.self)
    let canFinish = AsyncStream.makeStream(of: Void.self)

    store.addTask(forKey: .first, duplicateKeyBehavior: .cancelPrevious(wait: true)) {
      firstStarted.continuation.yield()
      await tracker.append("first-start")
      for await _ in canFinish.stream { break }
      await tracker.append("first-end")
    }

    for await _ in firstStarted.stream { break }

    let secondTask = store.addTask(
      forKey: .first,
      duplicateKeyBehavior: .cancelPrevious(wait: true)
    ) {
      await tracker.append("second-start")
      await tracker.append("second-end")
    }

    canFinish.continuation.yield()
    canFinish.continuation.finish()

    await secondTask.value

    let order = await tracker.allEvents

    // First should complete (even if cancelled, we wait), then second runs
    #expect(order.contains("first-end"))
    let firstEndIndex = try #require(order.firstIndex(of: "first-end"))
    let secondStartIndex = try #require(order.firstIndex(of: "second-start"))
    #expect(firstEndIndex < secondStartIndex)
  }

  @Test("wait behavior waits for previous without cancelling")
  func waitBehavior() async {
    let store = TaskStore<TestKey>()
    let tracker = OrderTracker()
    let firstStarted = AsyncStream.makeStream(of: Void.self)
    let canFinish = AsyncStream.makeStream(of: Void.self)

    store.addTask(forKey: .first, duplicateKeyBehavior: .wait) {
      firstStarted.continuation.yield()
      await tracker.append("first-start")
      for await _ in canFinish.stream { break }
      await tracker.append("first-end")
    }

    for await _ in firstStarted.stream { break }

    let secondTask = store.addTask(forKey: .first, duplicateKeyBehavior: .wait) {
      await tracker.append("second-start")
      await tracker.append("second-end")
    }

    canFinish.continuation.yield()
    canFinish.continuation.finish()

    await secondTask.value

    let order = await tracker.allEvents

    // First should complete fully, then second runs
    #expect(order == ["first-start", "first-end", "second-start", "second-end"])
  }

  @Test("runConcurrently runs both tasks at the same time")
  func runConcurrently() async {
    let store = TaskStore<TestKey>()
    let firstStarted = AsyncStream.makeStream(of: Void.self)
    let secondStarted = AsyncStream.makeStream(of: Void.self)
    let canFinish = AsyncStream.makeStream(of: Void.self)

    store.addTask(forKey: .first, duplicateKeyBehavior: .runConcurrently) {
      firstStarted.continuation.yield()
      for await _ in canFinish.stream { break }
    }

    store.addTask(forKey: .first, duplicateKeyBehavior: .runConcurrently) {
      secondStarted.continuation.yield()
      for await _ in canFinish.stream { break }
    }

    // Wait for both tasks to start (verifies they run concurrently)
    for await _ in firstStarted.stream { break }
    for await _ in secondStarted.stream { break }

    // Both tasks should have started - test passes if we get here
    canFinish.continuation.finish()
  }

  @Test("preferPrevious returns existing task without starting new one")
  func preferPrevious() async {
    let store = TaskStore<TestKey>()
    let firstRanCount = TestState(0)
    let secondRanCount = TestState(0)
    let firstStarted = AsyncStream.makeStream(of: Void.self)
    let canFinish = AsyncStream.makeStream(of: Void.self)

    let firstTask = store.addTask(forKey: .first, duplicateKeyBehavior: .preferPrevious) {
      firstStarted.continuation.yield()
      await firstRanCount.set(await firstRanCount.value + 1)
      for await _ in canFinish.stream { break }
    }

    for await _ in firstStarted.stream { break }

    let returnedTask = store.addTask(forKey: .first, duplicateKeyBehavior: .preferPrevious) {
      await secondRanCount.set(await secondRanCount.value + 1)
    }

    // Should return the same task
    canFinish.continuation.yield()
    canFinish.continuation.finish()

    await firstTask.value
    await returnedTask.value

    let firstCount = await firstRanCount.value
    let secondCount = await secondRanCount.value
    #expect(firstCount == 1)
    #expect(secondCount == 0)
  }

  // MARK: - Task ID Tracking

  @Test("Completed task does not remove newer task with same key")
  func completedTaskDoesNotRemoveNewer() async {
    let store = TaskStore<TestKey>()
    let firstStarted = AsyncStream.makeStream(of: Void.self)
    let firstFinished = AsyncStream.makeStream(of: Void.self)
    let secondStarted = AsyncStream.makeStream(of: Void.self)
    let secondCanFinish = AsyncStream.makeStream(of: Void.self)

    // Start first task
    store.addTask(forKey: .first, duplicateKeyBehavior: .runConcurrently) {
      firstStarted.continuation.yield()
      // Completes immediately after signaling
      firstFinished.continuation.yield()
      firstFinished.continuation.finish()
    }

    for await _ in firstStarted.stream { break }

    // Start second task that will outlive first
    let secondTask = store.addTask(forKey: .first, duplicateKeyBehavior: .runConcurrently) {
      secondStarted.continuation.yield()
      for await _ in secondCanFinish.stream { break }
    }

    for await _ in secondStarted.stream { break }

    // Wait for first task to complete
    for await _ in firstFinished.stream { break }
    // Second should still be tracked
    #expect(store.taskIsRunning(forKey: .first))

    secondCanFinish.continuation.yield()
    secondCanFinish.continuation.finish()

    await secondTask.value
    #expect(!store.taskIsRunning(forKey: .first))
  }

  @available(macOS 26.0, iOS 26.0, *)
  @Test("observation works as expected")
  @MainActor
  func observationWorks() async {
    let store = TaskStore<Int>()
    let loadingStream = Observations {
      store.taskIsRunning(forKey: 99)
    }
    let addTasks = Task {
      await Task.yield()
      store.addTask(forKey: 1) {
        await Task.yield()
      }
      await Task.yield()
      store.addTask(forKey: 99) {
        await Task.detached(priority: .background) { await Task.yield() }.value
      }
      await Task.yield()
      store.addTask(forKey: 99, duplicateKeyBehavior: .runConcurrently) {
        await Task.yield()
      }
      await store.currentTask(forKey: 1)?.value
      await store.currentTask(forKey: 99)?.value
    }
    let assertValues = Task {
      var values = [Bool]()
      for await value in loadingStream.removeDuplicates().prefix(3) {
        print(value)
        values.append(value)
      }
      #expect(values == [false, true, false])
    }
    _ = await (addTasks.value, assertValues.value)
  }

  @Test
  @MainActor
  func `task runs in different isolation`() async {
    let store = TaskStore<Int>()
    await confirmation { confirmation in
      await store.addTask(forKey: 1) {
        #expect(#isolation !== MainActor.shared)
        confirmation()
      }.value
    }
  }
}
