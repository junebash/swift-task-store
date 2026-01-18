//===----------------------------------------------------------------------===//
//
// This source file is part of the swift-task-store open source project
//
// Copyright (c) June Bash
//
// See LICENSE for license information
//
//===----------------------------------------------------------------------===//

import Foundation
import Observation

/// A type that manages concurrent `Task` operations, keyed by a hashable identifier.
///
/// `TaskStore` provides a centralized way to manage multiple concurrent async operations,
/// tracking their state and handling scenarios where multiple tasks may be requested for
/// the same key. This is particularly useful in SwiftUI applications using MVVM architecture
/// where you need to manage async operations triggered by user actions.
///
/// ## Overview
///
/// When building apps with Swift concurrency, a common pattern is to trigger async work
/// from button taps or other user interactions. Managing the lifecycle of these tasks—
/// especially handling cancellation and preventing duplicate work—can be error-prone.
/// `TaskStore` encapsulates this complexity.
///
/// ## Example Usage
///
/// ```swift
/// @Observable
/// @MainActor
/// final class MyModel {
///     let tasks = TaskStore<TaskKey>()
///
///     enum TaskKey: Hashable {
///         case fetchUser
///         case saveDocument
///         case uploadImage
///     }
///
///     func fetchUser() {
///         tasks.addTask(forKey: .fetchUser) {
///             // Perform async work
///             try? await Task.sleep(for: .seconds(1))
///         }
///     }
///
///     var isFetchingUser: Bool {
///         tasks.taskIsRunning(forKey: .fetchUser)
///     }
/// }
/// ```
///
/// ## Duplicate Key Behavior
///
/// When a task is added for a key that already has an active task, `TaskStore` can handle
/// the situation in several ways, configured via ``TaskStoreDuplicateKeyBehavior``:
///
/// - ``TaskStoreDuplicateKeyBehavior/cancelPrevious(wait:)``: Cancel the previous task
///   and optionally wait for it to finish before starting the new one.
/// - ``TaskStoreDuplicateKeyBehavior/wait``: Wait for the previous task to complete,
///   then run the new one.
/// - ``TaskStoreDuplicateKeyBehavior/runConcurrently``: Run both tasks at the same time.
/// - ``TaskStoreDuplicateKeyBehavior/preferPrevious``: Keep the existing task and ignore
///   the new request.
///
/// ## Observable Integration
///
/// `TaskStore` is marked with `@Observable`, so SwiftUI views can automatically update
/// when task states change. For example, you can bind a loading indicator to
/// ``taskIsRunning(forKey:)``.
///
/// ## Thread Safety
///
/// `TaskStore` cannot be passed between different isolation contexts. In Swift 6 language mode,
/// this is enforced by the compiler. It must remain in the isolation context in which it was
/// created.
@Observable
public final class TaskStore<Key: Hashable & Sendable> {
  /// Internal storage for task data, pairing tasks with unique identifiers
  /// to handle completion tracking correctly when multiple tasks share a key.
  
  /// Convenience type alias for duplicate key behavior configuration.
  public typealias DuplicateKeyBehavior = TaskStoreDuplicateKeyBehavior

  var currentTasks: [Key: TaskData] = [:]

  /// Creates a new, empty task store.
  @inlinable
  public init() {}
  
  /// Adds and starts a new task for the given key.
  ///
  /// If a task is already running for the specified key, the behavior is determined
  /// by the `duplicateKeyBehavior` parameter.
  ///
  /// - Parameters:
  ///   - key: The key identifying this task. Used to track, cancel, or check the
  ///     status of the task.
  ///   - duplicateKeyBehavior: How to handle the situation when a task is already
  ///     running for this key. Defaults to cancelling the previous task without
  ///     waiting for it to complete.
  ///   - priority: The priority of the task. Pass `nil` to use the priority from
  ///     the current task hierarchy.
  ///   - isolation: The actor isolation context. Defaults to capturing the caller's
  ///     isolation via `#isolation`. You typically don't need to specify this.
  ///   - operation: The async work to perform.
  ///
  /// - Returns: The created `Task`. You can use this to await the result or cancel
  ///   the task manually, though the store handles cleanup automatically.
  ///
  /// ## Example
  ///
  /// ```swift
  /// // Cancel any previous fetch and start a new one immediately
  /// tasks.addTask(forKey: .fetchData, duplicateKeyBehavior: .cancelPrevious(wait: false)) {
  ///     await fetchDataFromServer()
  /// }
  ///
  /// // Wait for the previous task to complete before starting
  /// tasks.addTask(forKey: .saveDocument, duplicateKeyBehavior: .wait) {
  ///     await saveDocument()
  /// }
  /// ```
  @discardableResult
  public func addTask(
    forKey key: Key,
    duplicateKeyBehavior: TaskStoreDuplicateKeyBehavior = .cancelPrevious(wait: false),
    priority: TaskPriority? = nil,
    isolation: isolated (any Actor)? = #isolation,
    operation: @escaping @Sendable () async -> Void
  ) -> Task<Void, Never> {
    let preferNewOptions = duplicateKeyBehavior.preferNewOptions
    let previousTask = self.currentTasks[key]?.task
    
    if let previousTask {
      guard let preferNewOptions else { return previousTask }
      if preferNewOptions.cancelPrevious {
        previousTask.cancel()
      }
    }
    
    let newTaskID = UUID()
    let newTask = Task(priority: priority) {
      await withTaskCancellationHandler {
        if let previousTask, let preferNewOptions, preferNewOptions.waitForPrevious {
          await previousTask.value
        }
        await operation()
        self.taskFinished(key: key, id: newTaskID, isolation: isolation)
      } onCancel: {
        previousTask?.cancel()
      }
    }
    
    self.currentTasks[key] = TaskData(id: newTaskID, task: newTask)
    return newTask
  }
  
  /// Called when a task completes to clean up internal state.
  ///
  /// Only removes the task if the stored ID matches, preventing issues when
  /// a newer task has replaced the completed one.
  private func taskFinished(key: Key, id: UUID, isolation: isolated (any Actor)?) {
    if currentTasks[key]?.id == id {
      currentTasks.removeValue(forKey: key)
    }
  }
  
  /// Cancels the task running for the specified key, if any.
  ///
  /// If no task is running for the key, this method does nothing.
  ///
  /// - Parameter key: The key identifying the task to cancel.
  public func cancelTask(forKey key: Key) {
    currentTasks[key]?.task.cancel()
  }
  
  /// Returns whether a task is currently running for the specified key.
  ///
  /// This property is observable, so SwiftUI views can automatically update
  /// when the task state changes.
  ///
  /// - Parameter key: The key to check.
  /// - Returns: `true` if a task is running for the key, `false` otherwise.
  ///
  /// ## Example
  ///
  /// ```swift
  /// Button("Fetch Data") {
  ///     model.fetchData()
  /// }
  /// .disabled(model.tasks.taskIsRunning(forKey: .fetchData))
  /// ```
  public func taskIsRunning(forKey key: Key) -> Bool {
    currentTasks.keys.contains(key)
  }

  /// Returns the task currently running for the specified key, if any.
  ///
  /// Use this method when you need direct access to the task, for example to
  /// await its completion or check its cancellation status.
  ///
  /// - Parameter key: The key identifying the task to retrieve.
  /// - Returns: The running task for the key, or `nil` if no task is running.
  ///
  /// ## Example
  ///
  /// ```swift
  /// // Wait for an existing task to complete
  /// if let existingTask = tasks.currentTask(forKey: .fetchData) {
  ///     await existingTask.value
  /// }
  /// ```
  public func currentTask(forKey key: Key) -> Task<Void, Never>? {
    currentTasks[key]?.task
  }

  /// Cancels all running tasks.
  ///
  /// This is useful for cleanup, such as when a view disappears.
  public func cancelAllTasks() {
    for taskData in currentTasks.values {
      taskData.task.cancel()
    }
  }
  
  /// The number of tasks currently running.
  public var runningTaskCount: Int {
    currentTasks.count
  }
  
  /// The keys of all currently running tasks.
  public var runningTaskKeys: Set<Key> {
    Set(currentTasks.keys)
  }
}
