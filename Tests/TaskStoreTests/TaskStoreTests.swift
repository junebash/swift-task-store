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
import Observation
import TaskStore

@Suite("TaskStore", .timeLimit(.minutes(1)))
@TestIsolation
struct TaskStoreTests {

  enum TestKey: Hashable, Sendable {
    case first
    case second
  }

  // MARK: - Tracking

  @Test(arguments: AddMethod.available)
  func `taskIsRunning is true only while the task runs`(method: AddMethod) async {
    let store = TaskStore<TestKey>()
    let started = Gate()
    let release = Gate()

    let task = store.add(method, forKey: .first) {
      await started.open()
      await release.wait()
    }
    await started.wait()
    #expect(store.taskIsRunning(forKey: .first))

    await release.open()
    await task.value
    #expect(!store.taskIsRunning(forKey: .first))
  }

  @Test(arguments: AddMethod.available)
  func `tasks for different keys are tracked independently`(method: AddMethod) async {
    let store = TaskStore<TestKey>()
    let release = Gate()

    let first = store.add(method, forKey: .first) {
      await release.wait()
    }
    await store.add(method, forKey: .second) {}.value

    #expect(store.taskIsRunning(forKey: .first))
    #expect(!store.taskIsRunning(forKey: .second))
    #expect(store.runningTaskKeys == [.first])
    #expect(store.runningTaskCount == 1)

    await release.open()
    await first.value
  }

  @Test(arguments: AddMethod.available)
  func `a finished task does not untrack a newer task for the same key`(method: AddMethod) async {
    let store = TaskStore<TestKey>()
    let releaseFirst = Gate()
    let releaseSecond = Gate()

    let first = store.add(method, forKey: .first) {
      await releaseFirst.wait()
    }
    let second = store.add(method, forKey: .first, .runConcurrently) {
      await releaseSecond.wait()
    }
    await releaseFirst.open()
    await first.value
    #expect(store.taskIsRunning(forKey: .first))

    await releaseSecond.open()
    await second.value
    #expect(!store.taskIsRunning(forKey: .first))
  }

  @Test
  func `taskIsRunning updates observers when a task starts and finishes`() async {
    let store = TaskStore<TestKey>()
    let release = Gate()
    // onChange runs synchronously inside the mutation, so each phase's
    // stream can be finished as soon as the mutation is done.
    func changeCount(during change: () async -> Void) async -> Int {
      let changes = AsyncStream.makeStream(of: Void.self)
      withObservationTracking {
        _ = store.taskIsRunning(forKey: .first)
      } onChange: {
        changes.continuation.yield()
      }
      await change()
      changes.continuation.finish()
      var count = 0
      for await _ in changes.stream {
        count += 1
      }
      return count
    }

    var task: Task<Void, Never>?
    let startChanges = await changeCount {
      task = store.addIsolatedTask(forKey: .first) {
        await release.wait()
      }
    }
    #expect(startChanges == 1)

    let finishChanges = await changeCount {
      await release.open()
      await task?.value
    }
    #expect(finishChanges == 1)
  }

  // MARK: - Cancellation

  @Test(arguments: AddMethod.available)
  func `cancelTask cancels the task for that key`(method: AddMethod) async {
    let store = TaskStore<TestKey>()
    let started = Gate()

    let task = store.add(method, forKey: .first) {
      await started.open()
      await waitUntilCancelled()
    }
    await started.wait()
    store.cancelTask(forKey: .first)
    #expect(task.isCancelled)

    task.cancel()
    await task.value
  }

  @Test(arguments: AddMethod.available)
  func `cancelAllTasks cancels every task`(method: AddMethod) async {
    let store = TaskStore<TestKey>()
    let firstStarted = Gate()
    let secondStarted = Gate()

    let first = store.add(method, forKey: .first) {
      await firstStarted.open()
      await waitUntilCancelled()
    }
    let second = store.add(method, forKey: .second) {
      await secondStarted.open()
      await waitUntilCancelled()
    }
    await firstStarted.wait()
    await secondStarted.wait()
    store.cancelAllTasks()
    #expect(first.isCancelled)
    #expect(second.isCancelled)

    first.cancel()
    second.cancel()
    await first.value
    await second.value
  }

  @Test(arguments: AddMethod.available, [TaskStoreDuplicateKeyBehavior.wait, .runConcurrently])
  func `cancelling the current task also cancels the task it replaced`(
    method: AddMethod,
    duplicateKeyBehavior: TaskStoreDuplicateKeyBehavior
  ) async {
    let store = TaskStore<TestKey>()

    let first = store.add(method, forKey: .first) {
      await waitUntilCancelled()
    }
    let second = store.add(method, forKey: .first, duplicateKeyBehavior) {}
    store.cancelTask(forKey: .first)

    await awaitCancellingOnTimeout(first)
    await second.value
  }

  // MARK: - Duplicate Key Behaviors

  @Test(arguments: AddMethod.available)
  func `cancelPrevious(wait: false) cancels the previous task and starts the new one right away`(
    method: AddMethod
  ) async {
    let store = TaskStore<TestKey>()
    let firstStarted = Gate()
    let releaseFirst = Gate()

    let first = store.add(method, forKey: .first) {
      await firstStarted.open()
      await releaseFirst.wait()
    }
    await firstStarted.wait()
    let second = store.add(method, forKey: .first, .cancelPrevious(wait: false)) {}
    #expect(first.isCancelled)

    await second.value
    await releaseFirst.open()
    await first.value
  }

  @Test(arguments: AddMethod.available)
  func `cancelPrevious(wait: true) cancels the previous task and waits for it`(
    method: AddMethod
  ) async {
    let store = TaskStore<TestKey>()
    let log = OrderTracker()
    let firstStarted = Gate()
    let releaseFirst = Gate()

    store.add(method, forKey: .first) {
      await firstStarted.open()
      await releaseFirst.wait()
      await log.append("first end, cancelled: \(Task.isCancelled)")
    }
    await firstStarted.wait()
    let second = store.add(method, forKey: .first, .cancelPrevious(wait: true)) {
      await log.append("second start")
    }
    await releaseFirst.open()
    await second.value

    #expect(await log.allEvents == ["first end, cancelled: true", "second start"])
  }

  @Test(arguments: AddMethod.available)
  func `wait runs the new task after the previous one finishes, without cancelling it`(
    method: AddMethod
  ) async {
    let store = TaskStore<TestKey>()
    let log = OrderTracker()
    let firstStarted = Gate()
    let releaseFirst = Gate()

    store.add(method, forKey: .first) {
      await firstStarted.open()
      await releaseFirst.wait()
      await log.append("first end, cancelled: \(Task.isCancelled)")
    }
    await firstStarted.wait()
    let second = store.add(method, forKey: .first, .wait) {
      await log.append("second start")
    }
    await releaseFirst.open()
    await second.value

    #expect(await log.allEvents == ["first end, cancelled: false", "second start"])
  }

  @Test(arguments: AddMethod.available)
  func `runConcurrently runs both tasks at once`(method: AddMethod) async {
    let store = TaskStore<TestKey>()
    let firstStarted = Gate()
    let releaseFirst = Gate()

    let first = store.add(method, forKey: .first) {
      await firstStarted.open()
      await releaseFirst.wait()
    }
    await firstStarted.wait()
    let second = store.add(method, forKey: .first, .runConcurrently) {}
    #expect(!first.isCancelled)

    await second.value
    await releaseFirst.open()
    await first.value
  }

  @Test(arguments: AddMethod.available)
  func `preferPrevious returns the running task and drops the new operation`(
    method: AddMethod
  ) async {
    let store = TaskStore<TestKey>()
    let release = Gate()
    let secondRan = TestState(false)

    let first = store.add(method, forKey: .first) {
      await release.wait()
    }
    let returned = store.add(method, forKey: .first, .preferPrevious) {
      await secondRan.set(true)
    }
    await release.open()
    await returned.value

    #expect(returned == first)
    #expect(await secondRan.value == false)
  }

  @Test(arguments: AddMethod.available)
  func `preferPrevious starts a new task when the current one was cancelled`(
    method: AddMethod
  ) async {
    let store = TaskStore<TestKey>()
    let release = Gate()
    let secondRan = TestState(false)

    let first = store.add(method, forKey: .first) {
      await release.wait()
    }
    store.cancelTask(forKey: .first)
    let second = store.add(method, forKey: .first, .preferPrevious) {
      await secondRan.set(true)
    }
    #expect(second != first)

    await release.open()
    await first.value
    await second.value
    #expect(await secondRan.value)
  }

  // MARK: - Isolation

  @Test
  @MainActor
  func `addConcurrentTask runs off the caller's actor`() async {
    let store = TaskStore<TestKey>()
    await confirmation { confirmation in
      await store.addConcurrentTask(forKey: .first) {
        #expect(#isolation !== MainActor.shared)
        confirmation()
      }.value
    }
  }

  @Test
  @MainActor
  func `addIsolatedTask runs on the caller's actor`() async {
    let store = TaskStore<TestKey>()
    await confirmation { confirmation in
      await store.addIsolatedTask(forKey: .first) {
        #expect(#isolation === MainActor.shared)
        confirmation()
      }.value
    }
  }

  @Test
  func `addIsolatedTask runs on an actor passed as an isolated parameter`() async {
    func addTask(
      to store: TaskStore<TestKey>,
      confirmation: Confirmation,
      isolation: isolated any Actor = #isolation
    ) -> Task<Void, Never> {
      store.addIsolatedTask(forKey: .first) {
        #expect(#isolation === TestIsolation.shared)
        confirmation()
      }
    }

    let store = TaskStore<TestKey>()
    await confirmation { confirmation in
      await addTask(to: store, confirmation: confirmation).value
    }
  }

  @Test
  func `a store owned by a custom actor serializes access to that actor's state`() async {
    actor Counter {
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

    let counter = Counter()
    async let decrements = [
      counter.decrement(),
      counter.decrement(),
      counter.decrement(),
    ]
    async let increments = [
      counter.increment(),
      counter.increment(),
      counter.increment(),
    ]
    for task in await decrements + increments {
      await task.value
    }
    #expect(await counter.count == 0)
  }
}

// MARK: - addImmediateTask

@Suite(.timeLimit(.minutes(1)))
@MainActor
struct TaskStoreImmediateTaskTests {

  @Test
  func `immediate task runs on the caller's actor`() async {
    guard #available(macOS 26.0, iOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *) else { return }
    let store = TaskStore<Int>()

    await confirmation { confirmation in
      await store.addImmediateTask(forKey: 0) {
        #expect(#isolation === MainActor.shared)
        confirmation()
      }.value
    }
  }

  @Test
  func `immediate task starts before addImmediateTask returns`() async {
    guard #available(macOS 26.0, iOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *) else { return }
    let store = TaskStore<Int>()
    let release = Gate()
    var started = false

    let task = store.addImmediateTask(forKey: 0) {
      started = true
      await release.wait()
    }
    #expect(started)

    await release.open()
    await task.value
  }

  @Test
  func `immediate task that finishes before returning is never tracked`() {
    guard #available(macOS 26.0, iOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *) else { return }
    let store = TaskStore<Int>()

    store.addImmediateTask(forKey: 0) {}

    #expect(!store.taskIsRunning(forKey: 0))
  }
}
