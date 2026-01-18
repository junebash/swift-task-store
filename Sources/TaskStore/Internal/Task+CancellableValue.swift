//===----------------------------------------------------------------------===//
//
// This source file is part of the swift-task-store open source project
//
// Copyright (c) June Bash
//
// See LICENSE for license information
//
//===----------------------------------------------------------------------===//

extension Task where Failure == Never {
  /// Awaits the task's value while propagating cancellation.
  ///
  /// Unlike the standard `value` property, `cancellableValue` will cancel
  /// the task if the awaiting context is cancelled. This is useful when
  /// you want parent task cancellation to propagate to child tasks.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let childTask = Task {
  ///     try? await Task.sleep(for: .seconds(10))
  ///     return "Done"
  /// }
  ///
  /// // If this task is cancelled, childTask will also be cancelled
  /// let result = await childTask.cancellableValue
  /// ```
  @usableFromInline
  var cancellableValue: Success {
    get async {
      await withTaskCancellationHandler {
        await self.value
      } onCancel: {
        self.cancel()
      }
    }
  }
}

extension Task where Failure == any Error {
  /// Awaits the task's value while propagating cancellation.
  ///
  /// Unlike the standard `value` property, `cancellableValue` will cancel
  /// the task if the awaiting context is cancelled. This is useful when
  /// you want parent task cancellation to propagate to child tasks.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let childTask = Task {
  ///     try await Task.sleep(for: .seconds(10))
  ///     return "Done"
  /// }
  ///
  /// // If this task is cancelled, childTask will also be cancelled
  /// let result = try await childTask.cancellableValue
  /// ```
  @usableFromInline
  var cancellableValue: Success {
    get async throws {
      try await withTaskCancellationHandler {
        try await self.value
      } onCancel: {
        self.cancel()
      }
    }
  }
}
