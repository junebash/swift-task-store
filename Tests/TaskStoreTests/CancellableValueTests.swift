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

@Suite("Task+CancellableValue Tests")
struct CancellableValueTests {

  @Test("cancellableValue returns result for non-throwing task")
  func cancellableValueReturnsResult() async {
    let task = Task<Int, Never> {
      42
    }

    let result = await task.cancellableValue
    #expect(result == 42)
  }

  @Test("cancellableValue returns result for throwing task")
  func cancellableValueReturnsResultThrowing() async throws {
    let task = Task<Int, any Error> {
      42
    }

    let result = try await task.cancellableValue
    #expect(result == 42)
  }

  @Test("cancellableValue propagates cancellation to non-throwing task")
  func cancellableValuePropagatesCancellation() async {
    let outerStarted = AsyncStream.makeStream(of: Void.self)
    let innerCancelled = AsyncStream.makeStream(of: Bool.self)
    let neverFinishes = AsyncStream<Void>.makeStream()

    let innerTask = Task<Void, Never> {
      for await _ in neverFinishes.stream { break }
      innerCancelled.continuation.yield(Task.isCancelled)
      innerCancelled.continuation.finish()
    }

    let outerTask = Task {
      outerStarted.continuation.yield()
      outerStarted.continuation.finish()
      await innerTask.cancellableValue
    }

    for await _ in outerStarted.stream { break }

    outerTask.cancel()
    neverFinishes.continuation.finish()

    for await wasCancelled in innerCancelled.stream {
      #expect(wasCancelled)
      break
    }
  }

  @Test("cancellableValue propagates cancellation to throwing task")
  func cancellableValuePropagatesCancellationThrowing() async {
    let outerStarted = AsyncStream.makeStream(of: Void.self)
    let innerCancelled = AsyncStream.makeStream(of: Bool.self)
    let neverFinishes = AsyncStream<Void>.makeStream()

    let innerTask = Task<Void, any Error> {
      for await _ in neverFinishes.stream { break }
      let wasCancelled = Task.isCancelled
      innerCancelled.continuation.yield(wasCancelled)
      innerCancelled.continuation.finish()
      if wasCancelled {
        throw CancellationError()
      }
    }

    let outerTask = Task {
      outerStarted.continuation.yield()
      outerStarted.continuation.finish()
      try? await innerTask.cancellableValue
    }

    for await _ in outerStarted.stream { break }

    outerTask.cancel()
    neverFinishes.continuation.finish()

    for await wasCancelled in innerCancelled.stream {
      #expect(wasCancelled)
      break
    }
  }
}
