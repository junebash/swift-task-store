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
@TestIsolation
struct TaskStoreTests {

  enum TestKey: Hashable, Sendable {
    case first
    case second
    case third
  }

  // MARK: - Basic Functionality

  @Test
  func `task runs and completes`() async {
    let store = TaskStore<TestKey>()

    await confirmation { didRun in
      let task = store.addConcurrentTask(forKey: .first) {
        didRun()
      }
      await task.value
    }

    #expect(!store.taskIsRunning(forKey: .first))
  }

  @Test
  func `taskIsRunning returns true while task is active`() async {
    let store = TaskStore<TestKey>()
    let started = AsyncStream.makeStream(of: Void.self)
    let canFinish = AsyncStream.makeStream(of: Void.self)

    let task = store.addConcurrentTask(forKey: .first) {
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

  @Test
  func `taskIsRunning returns false for unknown key`() {
    let store = TaskStore<TestKey>()
    #expect(!store.taskIsRunning(forKey: .first))
  }

  @Test
  func `cancelTask cancels running task`() async {
    let store = TaskStore<TestKey>()
    let started = AsyncStream.makeStream(of: Void.self)
    let cancelled = AsyncStream.makeStream(of: Bool.self)
    let neverFinishes = AsyncStream<Void>.makeStream()

    store.addConcurrentTask(forKey: .first) {
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

  @Test
  func `cancelTask does nothing for unknown key`() {
    let store = TaskStore<TestKey>()
    // Should not throw or crash
    store.cancelTask(forKey: .first)
  }

  // MARK: - Multiple Tasks

  @Test
  func `multiple tasks with different keys run concurrently`() async {
    let store = TaskStore<TestKey>()
    let firstStarted = AsyncStream.makeStream(of: Void.self)
    let secondStarted = AsyncStream.makeStream(of: Void.self)
    let canFinish = AsyncStream.makeStream(of: Void.self)

    store.addConcurrentTask(forKey: .first) {
      firstStarted.continuation.yield()
      for await _ in canFinish.stream { break }
    }

    store.addConcurrentTask(forKey: .second) {
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

  @Test
  func `cancelAllTasks cancels all running tasks`() async {
    let store = TaskStore<TestKey>()
    let firstStarted = AsyncStream.makeStream(of: Void.self)
    let secondStarted = AsyncStream.makeStream(of: Void.self)
    let firstCancelled = AsyncStream.makeStream(of: Bool.self)
    let secondCancelled = AsyncStream.makeStream(of: Bool.self)
    let firstNeverFinishes = AsyncStream<Void>.makeStream()
    let secondNeverFinishes = AsyncStream<Void>.makeStream()

    store.addConcurrentTask(forKey: .first) {
      firstStarted.continuation.yield()
      firstStarted.continuation.finish()
      for await _ in firstNeverFinishes.stream { break }
      firstCancelled.continuation.yield(Task.isCancelled)
      firstCancelled.continuation.finish()
    }

    store.addConcurrentTask(forKey: .second) {
      secondStarted.continuation.yield()
      secondStarted.continuation.finish()
      for await _ in secondNeverFinishes.stream { break }
      secondCancelled.continuation.yield(Task.isCancelled)
      secondCancelled.continuation.finish()
    }

    // Wait for both tasks to start
    for await _ in firstStarted.stream { break }
    for await _ in secondStarted.stream { break }

    store.cancelAllTasks()
    firstNeverFinishes.continuation.finish()
    secondNeverFinishes.continuation.finish()

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

  @Test
  func `cancelPrevious(wait: false) cancels previous and runs new immediately`() async throws {
    let store = TaskStore<TestKey>()
    let firstStarted = AsyncStream.makeStream(of: Void.self)
    let firstCancelled = AsyncStream.makeStream(of: Bool.self)
    let neverFinishes = AsyncStream<Void>.makeStream()

    await confirmation(expectedCount: 2) { taskRan in
      store.addConcurrentTask(forKey: .first, duplicateKeyBehavior: .cancelPrevious(wait: false)) {
        taskRan()
        firstStarted.continuation.yield()
        for await _ in neverFinishes.stream { break }
        firstCancelled.continuation.yield(Task.isCancelled)
        firstCancelled.continuation.finish()
      }

      for await _ in firstStarted.stream { break }

      let secondTask = store.addConcurrentTask(
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

  @Test
  func `cancelPrevious(wait: true) cancels previous and waits before running new`() async throws {
    let store = TaskStore<TestKey>()
    let tracker = OrderTracker()
    let firstStarted = AsyncStream.makeStream(of: Void.self)
    let canFinish = AsyncStream.makeStream(of: Void.self)

    store.addConcurrentTask(forKey: .first, duplicateKeyBehavior: .cancelPrevious(wait: true)) {
      firstStarted.continuation.yield()
      await tracker.append("first-start")
      for await _ in canFinish.stream { break }
      await tracker.append("first-end")
    }

    for await _ in firstStarted.stream { break }

    let secondTask = store.addConcurrentTask(
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

  @Test
  func `wait behavior waits for previous without cancelling`() async {
    let store = TaskStore<TestKey>()
    let tracker = OrderTracker()
    let firstStarted = AsyncStream.makeStream(of: Void.self)
    let canFinish = AsyncStream.makeStream(of: Void.self)

    store.addConcurrentTask(forKey: .first, duplicateKeyBehavior: .wait) {
      firstStarted.continuation.yield()
      await tracker.append("first-start")
      for await _ in canFinish.stream { break }
      await tracker.append("first-end")
    }

    for await _ in firstStarted.stream { break }

    let secondTask = store.addConcurrentTask(forKey: .first, duplicateKeyBehavior: .wait) {
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

  @Test
  func `runConcurrently runs both tasks at the same time`() async {
    let store = TaskStore<TestKey>()
    let firstStarted = AsyncStream.makeStream(of: Void.self)
    let secondStarted = AsyncStream.makeStream(of: Void.self)
    let canFinish = AsyncStream.makeStream(of: Void.self)

    store.addConcurrentTask(forKey: .first, duplicateKeyBehavior: .runConcurrently) {
      firstStarted.continuation.yield()
      for await _ in canFinish.stream { break }
    }

    store.addConcurrentTask(forKey: .first, duplicateKeyBehavior: .runConcurrently) {
      secondStarted.continuation.yield()
      for await _ in canFinish.stream { break }
    }

    // Wait for both tasks to start (verifies they run concurrently)
    for await _ in firstStarted.stream { break }
    for await _ in secondStarted.stream { break }

    // Both tasks should have started - test passes if we get here
    canFinish.continuation.finish()
  }

  @Test
  func `preferPrevious returns existing task without starting new one`() async {
    let store = TaskStore<TestKey>()
    let firstRanCount = TestState(0)
    let secondRanCount = TestState(0)
    let firstStarted = AsyncStream.makeStream(of: Void.self)
    let canFinish = AsyncStream.makeStream(of: Void.self)

    let firstTask = store.addConcurrentTask(forKey: .first, duplicateKeyBehavior: .preferPrevious) {
      firstStarted.continuation.yield()
      await firstRanCount.set(await firstRanCount.value + 1)
      for await _ in canFinish.stream { break }
    }

    for await _ in firstStarted.stream { break }

    let returnedTask = store.addConcurrentTask(forKey: .first, duplicateKeyBehavior: .preferPrevious) {
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

  @Test
  func `completed task does not remove newer task with same key`() async {
    let store = TaskStore<TestKey>()
    let firstStarted = AsyncStream.makeStream(of: Void.self)
    let firstFinished = AsyncStream.makeStream(of: Void.self)
    let secondStarted = AsyncStream.makeStream(of: Void.self)
    let secondCanFinish = AsyncStream.makeStream(of: Void.self)

    // Start first task
    store.addConcurrentTask(forKey: .first, duplicateKeyBehavior: .runConcurrently) {
      firstStarted.continuation.yield()
      // Completes immediately after signaling
      firstFinished.continuation.yield()
      firstFinished.continuation.finish()
    }

    for await _ in firstStarted.stream { break }

    // Start second task that will outlive first
    let secondTask = store.addConcurrentTask(forKey: .first, duplicateKeyBehavior: .runConcurrently) {
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
  @Test
  @MainActor
  func `observation works as expected`() async {
    let store = TaskStore<Int>()
    let loadingStream = Observations {
      store.taskIsRunning(forKey: 99)
    }
    let addTasks = Task {
      await Task.yield()
      store.addConcurrentTask(forKey: 1) {
        await Task.yield()
      }
      await Task.yield()
      store.addConcurrentTask(forKey: 99) {
        await Task.detached(priority: .background) { await Task.yield() }.value
      }
      await Task.yield()
      store.addConcurrentTask(forKey: 99, duplicateKeyBehavior: .runConcurrently) {
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

  // MARK: - Isolation Tests

  @Test
  @MainActor
  func `addConcurrentTask runs in different isolation from caller`() async {
    let store = TaskStore<Int>()
    await confirmation { confirmation in
      await store.addConcurrentTask(forKey: 1) {
        #expect(#isolation !== MainActor.shared)
        confirmation()
      }.value
    }
  }

  @Test
  @MainActor
  func `addIsolatedTask runs in same isolation as caller`() async {
    let store = TaskStore<Int>()
    await confirmation { confirmation in
      await store.addIsolatedTask(forKey: 1) {
        #expect(#isolation === MainActor.shared)
        confirmation()
      }.value
    }
  }

  @Test
  func `other isolations work and don't crash or anything`() async {
    actor Isolation {
      let store = TaskStore<Int>()

      var count = 0

      func increment() -> Task<Void, Never> {
        store.addIsolatedTask(forKey: 0, duplicateKeyBehavior: .runConcurrently) {
          await Task.yield()
          count += 1
        }
      }

      func decrement() -> Task<Void, Never> {
        store.addConcurrentTask(forKey: 1, duplicateKeyBehavior: .runConcurrently) {
          await Task.yield()
          await self._decrement()
        }
      }

      private func _decrement() {
        count -= 1
      }
    }

    let isolation = Isolation()
    await isolation.increment().value
    #expect(await isolation.count == 1)

    await isolation.decrement().value
    #expect(await isolation.count == 0)

    async let decrs = [
      isolation.decrement(),
      isolation.decrement(),
      isolation.decrement()
    ]
    async let incrs = [
      isolation.increment(),
      isolation.increment(),
      isolation.increment()
    ]
    for d in await decrs {
      await d.value
    }
    for i in await incrs {
      await i.value
    }
    #expect(await isolation.count == 0)
  }

  // MARK: - addIsolatedTask Tests

  @Test
  @MainActor
  func `isolated task runs and completes`() async {
    let store = TaskStore<TestKey>()

    await confirmation { didRun in
      let task = store.addIsolatedTask(forKey: .first) {
        didRun()
      }
      await task.value
    }

    #expect(!store.taskIsRunning(forKey: .first))
  }

  @Test
  @MainActor
  func `isolated taskIsRunning returns true while task is active`() async {
    let store = TaskStore<TestKey>()
    let started = AsyncStream.makeStream(of: Void.self)
    let canFinish = AsyncStream.makeStream(of: Void.self)

    let task = store.addIsolatedTask(forKey: .first) {
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

  @Test
  @MainActor
  func `isolated cancelTask cancels running task`() async {
    let store = TaskStore<TestKey>()
    let started = AsyncStream.makeStream(of: Void.self)
    let cancelled = AsyncStream.makeStream(of: Bool.self)
    let neverFinishes = AsyncStream<Void>.makeStream()

    store.addIsolatedTask(forKey: .first) {
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

  @Test
  @MainActor
  func `isolated cancelPrevious(wait: false) cancels previous and runs new immediately`() async throws {
    let store = TaskStore<TestKey>()
    let firstStarted = AsyncStream.makeStream(of: Void.self)
    let firstCancelled = AsyncStream.makeStream(of: Bool.self)
    let neverFinishes = AsyncStream<Void>.makeStream()

    await confirmation(expectedCount: 2) { taskRan in
      store.addIsolatedTask(forKey: .first, duplicateKeyBehavior: .cancelPrevious(wait: false)) {
        taskRan()
        firstStarted.continuation.yield()
        for await _ in neverFinishes.stream { break }
        firstCancelled.continuation.yield(Task.isCancelled)
        firstCancelled.continuation.finish()
      }

      for await _ in firstStarted.stream { break }

      let secondTask = store.addIsolatedTask(
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

  @Test
  @MainActor
  func `isolated wait behavior waits for previous without cancelling`() async {
    let store = TaskStore<TestKey>()
    let tracker = OrderTracker()
    let firstStarted = AsyncStream.makeStream(of: Void.self)
    let canFinish = AsyncStream.makeStream(of: Void.self)

    store.addIsolatedTask(forKey: .first, duplicateKeyBehavior: .wait) {
      firstStarted.continuation.yield()
      await tracker.append("first-start")
      for await _ in canFinish.stream { break }
      await tracker.append("first-end")
    }

    for await _ in firstStarted.stream { break }

    let secondTask = store.addIsolatedTask(forKey: .first, duplicateKeyBehavior: .wait) {
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

  @Test
  @MainActor
  func `isolated preferPrevious returns existing task without starting new one`() async {
    let store = TaskStore<TestKey>()
    let firstRanCount = TestState(0)
    let secondRanCount = TestState(0)
    let firstStarted = AsyncStream.makeStream(of: Void.self)
    let canFinish = AsyncStream.makeStream(of: Void.self)

    let firstTask = store.addIsolatedTask(forKey: .first, duplicateKeyBehavior: .preferPrevious) {
      firstStarted.continuation.yield()
      await firstRanCount.set(await firstRanCount.value + 1)
      for await _ in canFinish.stream { break }
    }

    for await _ in firstStarted.stream { break }

    let returnedTask = store.addIsolatedTask(forKey: .first, duplicateKeyBehavior: .preferPrevious) {
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
}

// MARK: - addImmediateTask Tests

@TestIsolation
struct TaskStoreImmediateTaskTests {

  enum TestKey: Hashable, Sendable {
    case first
    case second
  }

  // MARK: - Basic Functionality

  @Test
  @MainActor
  func `immediate task runs and completes`() async {
    guard #available(macOS 26.0, iOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *) else { return }
    let store = TaskStore<TestKey>()

    await confirmation { didRun in
      let task = store.addImmediateTask(forKey: .first) {
        didRun()
      }
      await task.value
    }

    #expect(!store.taskIsRunning(forKey: .first))
  }

  @Test
  @MainActor
  func `immediate taskIsRunning returns true while task is active`() async {
    guard #available(macOS 26.0, iOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *) else { return }
    let store = TaskStore<TestKey>()
    let canFinish = AsyncStream.makeStream(of: Void.self)

    let task = store.addImmediateTask(forKey: .first) {
      for await _ in canFinish.stream { break }
    }

    // Task should be running since it suspended on the stream
    #expect(store.taskIsRunning(forKey: .first))

    canFinish.continuation.yield()
    canFinish.continuation.finish()

    await task.value
    #expect(!store.taskIsRunning(forKey: .first))
  }

  @Test
  @MainActor
  func `immediate task inherits caller actor isolation`() async {
    guard #available(macOS 26.0, iOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *) else { return }
    let store = TaskStore<TestKey>()

    await confirmation { confirmation in
      await store.addImmediateTask(forKey: .first) {
        #expect(#isolation === MainActor.shared)
        confirmation()
      }.value
    }
  }

  // MARK: - Cancellation

  @Test
  @MainActor
  func `immediate cancelTask cancels running task`() async {
    guard #available(macOS 26.0, iOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *) else { return }
    let store = TaskStore<TestKey>()
    let cancelled = AsyncStream.makeStream(of: Bool.self)
    let neverFinishes = AsyncStream<Void>.makeStream()

    store.addImmediateTask(forKey: .first) {
      for await _ in neverFinishes.stream { break }
      cancelled.continuation.yield(Task.isCancelled)
      cancelled.continuation.finish()
    }

    store.cancelTask(forKey: .first)
    neverFinishes.continuation.finish()

    for await wasCancelled in cancelled.stream {
      #expect(wasCancelled)
      break
    }
  }

  // MARK: - Duplicate Key Behaviors

  @Test
  @MainActor
  func `immediate cancelPrevious(wait: false) cancels previous and runs new immediately`() async throws {
    guard #available(macOS 26.0, iOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *) else { return }
    let store = TaskStore<TestKey>()
    let firstCancelled = AsyncStream.makeStream(of: Bool.self)
    let neverFinishes = AsyncStream<Void>.makeStream()

    await confirmation(expectedCount: 2) { taskRan in
      store.addImmediateTask(forKey: .first, duplicateKeyBehavior: .cancelPrevious(wait: false)) {
        taskRan()
        for await _ in neverFinishes.stream { break }
        firstCancelled.continuation.yield(Task.isCancelled)
        firstCancelled.continuation.finish()
      }

      let secondTask = store.addImmediateTask(
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

  @Test
  @MainActor
  func `immediate cancelPrevious(wait: true) cancels previous and waits before running new`() async throws {
    guard #available(macOS 26.0, iOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *) else { return }
    let store = TaskStore<TestKey>()
    let tracker = OrderTracker()
    let canFinish = AsyncStream.makeStream(of: Void.self)

    store.addImmediateTask(forKey: .first, duplicateKeyBehavior: .cancelPrevious(wait: true)) {
      await tracker.append("first-start")
      for await _ in canFinish.stream { break }
      await tracker.append("first-end")
    }

    let secondTask = store.addImmediateTask(
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

  @Test
  @MainActor
  func `immediate wait behavior waits for previous without cancelling`() async {
    guard #available(macOS 26.0, iOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *) else { return }
    let store = TaskStore<TestKey>()
    let tracker = OrderTracker()
    let canFinish = AsyncStream.makeStream(of: Void.self)

    store.addImmediateTask(forKey: .first, duplicateKeyBehavior: .wait) {
      await tracker.append("first-start")
      for await _ in canFinish.stream { break }
      await tracker.append("first-end")
    }

    let secondTask = store.addImmediateTask(forKey: .first, duplicateKeyBehavior: .wait) {
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

  @Test
  @MainActor
  func `immediate preferPrevious returns existing task without starting new one`() async {
    guard #available(macOS 26.0, iOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *) else { return }
    let store = TaskStore<TestKey>()
    let firstRanCount = TestState(0)
    let secondRanCount = TestState(0)
    let canFinish = AsyncStream.makeStream(of: Void.self)

    let firstTask = store.addImmediateTask(forKey: .first, duplicateKeyBehavior: .preferPrevious) {
      await firstRanCount.set(await firstRanCount.value + 1)
      for await _ in canFinish.stream { break }
    }

    let returnedTask = store.addImmediateTask(forKey: .first, duplicateKeyBehavior: .preferPrevious) {
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

  @Test
  @MainActor
  func `immediate runConcurrently runs both tasks`() async {
    guard #available(macOS 26.0, iOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *) else { return }
    let store = TaskStore<TestKey>()
    let tracker = OrderTracker()
    let canFinish = AsyncStream.makeStream(of: Void.self)

    store.addImmediateTask(forKey: .first, duplicateKeyBehavior: .runConcurrently) {
      await tracker.append("first-start")
      for await _ in canFinish.stream { break }
      await tracker.append("first-end")
    }

    let secondTask = store.addImmediateTask(forKey: .first, duplicateKeyBehavior: .runConcurrently) {
      await tracker.append("second-start")
      for await _ in canFinish.stream { break }
      await tracker.append("second-end")
    }

    canFinish.continuation.finish()
    await secondTask.value

    let order = await tracker.allEvents
    #expect(order.contains("first-start"))
    #expect(order.contains("second-start"))
  }

  // MARK: - Task Cleanup

  @Test
  @MainActor
  func `immediate task is removed from store on completion`() async {
    guard #available(macOS 26.0, iOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *) else { return }
    let store = TaskStore<TestKey>()

    let task = store.addImmediateTask(forKey: .first) {
      // Completes immediately
    }

    await task.value
    #expect(!store.taskIsRunning(forKey: .first))
    #expect(store.runningTaskCount == 0)
  }

  @Test
  @MainActor
  func `immediate task completes immediately when synchronous`() async {
    guard #available(macOS 26.0, iOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *) else { return }
    let store = TaskStore<Int>()
    store.addImmediateTask(forKey: 0) {
      var a = 0
      for _ in 1...100 {
        a += 1
      }
      #expect(a == 100)
    }
    #expect(!store.taskIsRunning(forKey: 0))
  }
}
