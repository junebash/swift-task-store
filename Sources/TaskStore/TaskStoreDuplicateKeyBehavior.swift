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
/// tasks.addConcurrentTask(forKey: .search, duplicateKeyBehavior: .cancelPrevious(wait: false)) {
///     await performSearch(query)
/// }
///
/// // For document saves, wait for the previous save to complete
/// tasks.addIsolatedTask(forKey: .save, duplicateKeyBehavior: .wait) {
///     await self.saveDocument()
/// }
///
/// // For independent uploads, run them all
/// tasks.addConcurrentTask(forKey: .upload, duplicateKeyBehavior: .runConcurrently) {
///     await uploadFile(file)
/// }
///
/// // For refreshes, keep the one already in flight
/// tasks.addIsolatedTask(forKey: .refresh, duplicateKeyBehavior: .preferPrevious) {
///     await self.refresh()
/// }
/// ```
public struct TaskStoreDuplicateKeyBehavior: Hashable, Sendable {
  struct PreferNewOptions: Hashable, Sendable {
    var cancelPrevious: Bool
    var waitForPrevious: Bool
  }

  /// `nil` means prefer the previous task.
  var preferNewOptions: PreferNewOptions?

  /// Wait for the previous task to complete, then run the new task.
  ///
  /// The previous task is not cancelled; it runs to completion before the
  /// new task starts.
  public static var wait: Self {
    Self(preferNewOptions: .init(cancelPrevious: false, waitForPrevious: true))
  }

  /// Cancel the previous task and optionally wait for it to complete.
  ///
  /// - Parameter wait: If `true`, wait for the previous task to finish
  ///   (after cancellation) before starting the new task. If `false`,
  ///   start the new task immediately.
  /// - Returns: A behavior configuration.
  public static func cancelPrevious(wait: Bool) -> Self {
    Self(preferNewOptions: .init(cancelPrevious: true, waitForPrevious: wait))
  }

  /// Run the new task concurrently with the existing one.
  ///
  /// Neither task is cancelled, and the new task starts immediately
  /// without waiting for the previous one.
  public static var runConcurrently: Self {
    Self(preferNewOptions: .init(cancelPrevious: false, waitForPrevious: false))
  }

  /// Prefer the existing task; don't start a new one.
  ///
  /// When a task is already running for the key, adding a task returns the
  /// existing task without starting a new one, even if the existing task has
  /// been cancelled and is still finishing. The two never overlap; use
  /// ``cancelPrevious(wait:)`` to replace the existing task instead.
  public static var preferPrevious: Self {
    Self(preferNewOptions: nil)
  }
}
