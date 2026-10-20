# Claude Code Instructions

## Project Overview

swift-task-store is a Swift 6 library providing `TaskStore`, an observable container for managing keyed async tasks with configurable duplicate-key handling.

## Background

- [Task Management in Swift Part 1: The Problem](https://www.junebash.com/posts/task-management-in-swift-part-1-the-problem/)
- [Task Management in Swift Part 2: Introducing the TaskStore](https://www.junebash.com/posts/task-management-in-swift-part-2-introducing-the/)
- [Task Management in Swift Part 3: Duplicate Key Behavior](https://www.junebash.com/posts/task-management-in-swift-part-3-duplicate-key/)

## Build & Test

```bash
swift build    # Build the library
swift test     # Run all tests
```

## Architecture

- `TaskStore<Key>` - Main `@Observable` class holding at most one current task per key
- `TaskStoreDuplicateKeyBehavior` - Value type configuring how duplicate keys are handled
- `TaskNameProvider<Key>` - Struct wrapping a `(Key) -> String?` closure for task naming
  - Built-in: `.keyDescription`, `.constant("name")`, `.fromKey { ... }`
  - Modifiers: `.withPrefix("prefix")`, `.withIncrementingSuffix()`
- Three task creation methods:
  - `addConcurrentTask` - Runs on global concurrent executor (but still propagates TaskLocal values, unlike `Task.detached`)
  - `addIsolatedTask` - Inherits caller's actor isolation (like `Task.init`)
  - `addImmediateTask` - Uses `Task.immediate` (Swift 6.2+, SE-0472) to run synchronously until first suspension point

## Key Implementation Details

- Uses `isolation: isolated any Actor = #isolation` parameter to capture caller's actor context for thread safety
- Internal `TaskData` struct pairs tasks with IDs so a replaced task that finishes later doesn't remove its replacement
- A replaced task is no longer tracked; cancelling the current task cancels the tasks it replaced through its `onCancel` handler
- A task cancelled before its operation starts skips the operation
- Tasks capture the store weakly, and `deinit` cancels all current tasks
- Operations don't use `@_implicitSelfCapture`, so callers must write `self.`
- Cannot conform to `Sendable` due to `@Observable` mutable state; isolation is handled via the `isolation` parameter instead

## Testing

Tests use Swift Testing framework with:
- `@Test(arguments: AddMethod.available)` with `store.add(method, ...)` to run behavior tests against every add method
- `actor Gate` for start/release signals; waiting ignores cancellation, so a task can stay blocked after being cancelled
- `waitUntilCancelled()` for operations that should run until cancelled
- `actor TestState<T>` for thread-safe mutable state in tests
- `actor OrderTracker` for tracking event ordering

Prefer asserting `isCancelled` right after cancelling and unblocking tasks from the test, over awaiting a task that only the store can finish; such tests hang instead of failing.

Avoid using `confirmation()` for tasks that start asynchronously without awaiting inside the confirmation block.

## Code Style

- Empty line after imports
- Empty lines should have no whitespace
- Never force unwrap or force try
