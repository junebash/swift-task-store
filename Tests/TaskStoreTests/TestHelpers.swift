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
import TaskStore

/// Thread-safe container for tracking values in tests.
actor TestState<T: Sendable> {
  private var _value: T

  init(_ initial: T) {
    self._value = initial
  }

  var value: T { _value }

  func set(_ newValue: T) {
    _value = newValue
  }
}

/// Thread-safe container for tracking ordered events in tests.
actor OrderTracker {
  private var events: [String] = []

  func append(_ event: String) {
    events.append(event)
  }

  var allEvents: [String] { events }
}

/// A one-shot signal. Waiting ignores cancellation, so a task can stay blocked
/// after it has been cancelled.
actor Gate {
  private var isOpen = false
  private var waiters: [CheckedContinuation<Void, Never>] = []

  func open() {
    isOpen = true
    for waiter in waiters {
      waiter.resume()
    }
    waiters = []
  }

  func wait() async {
    if isOpen { return }
    await withCheckedContinuation { waiters.append($0) }
  }
}

/// Suspends until the current task is cancelled.
func waitUntilCancelled() async {
  try? await Task.sleep(for: .seconds(60 * 60 * 24 * 365))
}

/// Awaits `task`, cancelling it if the test is cancelled, so a time limit can end a test
/// whose task never finishes.
func awaitCancellingOnTimeout(_ task: Task<Void, Never>) async {
  await withTaskCancellationHandler {
    await task.value
  } onCancel: {
    task.cancel()
  }
}

enum AddMethod: CaseIterable, Sendable {
  case concurrent
  case isolated
  case immediate

  static var available: [Self] {
    if #available(macOS 26.0, iOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *) {
      allCases
    } else {
      [.concurrent, .isolated]
    }
  }
}

extension TaskStore {
  @discardableResult
  func add(
    _ method: AddMethod,
    forKey key: Key,
    _ duplicateKeyBehavior: TaskStoreDuplicateKeyBehavior = .cancelPrevious(wait: false),
    isolation: isolated any Actor = #isolation,
    operation: @escaping @Sendable () async -> Void
  ) -> Task<Void, Never> {
    switch method {
    case .concurrent:
      return addConcurrentTask(
        forKey: key,
        duplicateKeyBehavior: duplicateKeyBehavior,
        isolation: isolation,
        operation: operation
      )
    case .isolated:
      return addIsolatedTask(
        forKey: key,
        duplicateKeyBehavior: duplicateKeyBehavior,
        isolation: isolation
      ) {
        await operation()
      }
    case .immediate:
      guard #available(macOS 26.0, iOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *) else {
        Issue.record("addImmediateTask is unavailable on this OS")
        return Task {}
      }
      return addImmediateTask(
        forKey: key,
        duplicateKeyBehavior: duplicateKeyBehavior,
        isolation: isolation
      ) {
        await operation()
      }
    }
  }
}

@globalActor
actor TestIsolation {
  static let shared = TestIsolation()
}
