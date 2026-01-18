//===----------------------------------------------------------------------===//
//
// This source file is part of the swift-task-store open source project
//
// Copyright (c) June Bash
//
// See LICENSE for license information
//
//===----------------------------------------------------------------------===//

/// Configuration for how ``TaskStore`` handles adding a task when one is already
/// running for the same key.
///
/// ## Available Behaviors
///
/// - ``cancelPrevious(wait:)``: Cancel the existing task. If `wait` is `true`,
///   wait for it to finish before starting the new task.
/// - ``wait``: Wait for the existing task to complete, then run the new task.
/// - ``runConcurrently``: Run both tasks simultaneously.
/// - ``preferPrevious``: Keep the existing task and return it; don't start a new one.
///
/// ## Example
///
/// ```swift
/// // For a search field, cancel previous searches immediately
/// tasks.addTask(forKey: .search, duplicateKeyBehavior: .cancelPrevious(wait: false)) {
///     await performSearch(query)
/// }
///
/// // For document saves, wait for the previous save to complete
/// tasks.addTask(forKey: .save, duplicateKeyBehavior: .wait) {
///     await saveDocument()
/// }
///
/// // For independent uploads, run them all
/// tasks.addTask(forKey: .upload, duplicateKeyBehavior: .runConcurrently) {
///     await uploadFile(file)
/// }
///
/// // For expensive computations, prefer keeping the existing one
/// tasks.addTask(forKey: .compute, duplicateKeyBehavior: .preferPrevious) {
///     await expensiveComputation()
/// }
/// ```
public struct TaskStoreDuplicateKeyBehavior: Hashable, Sendable {
  @usableFromInline
  struct PreferNewOptions: Hashable, Sendable {
    @usableFromInline
    var cancelPrevious: Bool
    
    @usableFromInline
    var waitForPrevious: Bool
    
    @usableFromInline
    init(cancelPrevious: Bool, waitForPrevious: Bool) {
      self.cancelPrevious = cancelPrevious
      self.waitForPrevious = waitForPrevious
    }
  }
  
  @usableFromInline
  var preferNewOptions: PreferNewOptions?
  
  @inlinable
  init(preferNewOptions: PreferNewOptions? = nil) {
    self.preferNewOptions = preferNewOptions
  }
  
  /// Whether to prefer the existing task over a new one.
  ///
  /// When `true`, adding a task for a key that already has a running task
  /// will return the existing task without starting a new one.
  @inlinable
  public var preferPrevious: Bool {
    preferNewOptions == nil
  }
  
  /// Whether to cancel the previous task when adding a new one.
  ///
  /// Only applies when ``preferPrevious`` is `false`.
  @inlinable
  public var cancelPrevious: Bool {
    preferNewOptions?.cancelPrevious ?? false
  }
  
  /// Whether to wait for the previous task to complete before running the new one.
  ///
  /// Only applies when ``preferPrevious`` is `false`.
  @inlinable
  public var waitForPrevious: Bool {
    preferNewOptions?.waitForPrevious ?? true
  }
  
  /// Whether a new task will be started.
  ///
  /// Returns `false` only when ``preferPrevious`` is `true` and a task
  /// is already running.
  @inlinable
  public var runNewTask: Bool {
    preferNewOptions != nil
  }
  
  /// Wait for the previous task to complete, then run the new task.
  ///
  /// The previous task is not cancelled; it runs to completion before the
  /// new task starts.
  @inlinable
  public static var wait: Self {
    Self(preferNewOptions: .init(cancelPrevious: false, waitForPrevious: true))
  }
  
  /// Cancel the previous task and optionally wait for it to complete.
  ///
  /// - Parameter wait: If `true`, wait for the previous task to finish
  ///   (after cancellation) before starting the new task. If `false`,
  ///   start the new task immediately.
  /// - Returns: A behavior configuration.
  @inlinable
  public static func cancelPrevious(wait: Bool) -> Self {
    Self(preferNewOptions: .init(cancelPrevious: true, waitForPrevious: wait))
  }
  
  /// Run the new task concurrently with the existing one.
  ///
  /// Neither task is cancelled, and the new task starts immediately
  /// without waiting for the previous one.
  @inlinable
  public static var runConcurrently: Self {
    Self(preferNewOptions: .init(cancelPrevious: false, waitForPrevious: false))
  }
  
  /// Prefer the existing task; don't start a new one.
  ///
  /// When a task is already running for the key, ``TaskStore/addTask(forKey:duplicateKeyBehavior:priority:isolation:operation:)``
  /// returns the existing task without starting a new one.
  @inlinable
  public static var preferPrevious: Self {
    Self()
  }
}
