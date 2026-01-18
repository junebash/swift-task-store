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

- `TaskStore<Key>` - Main `@Observable` class managing tasks by key
- `TaskStoreDuplicateKeyBehavior` - Value type configuring how duplicate keys are handled
- Two task creation methods:
  - `addConcurrentTask` - Runs on global concurrent executor (but still propagates TaskLocal values, unlike `Task.detached`)
  - `addIsolatedTask` - Inherits caller's actor isolation (like `Task.init`)

## Key Implementation Details

- Uses `isolation: isolated (any Actor)? = #isolation` parameter to capture caller's actor context for thread safety
- Internal `TaskData` struct pairs tasks with IDs to prevent stale task cleanup when tasks share keys
- Cannot conform to `Sendable` due to `@Observable` mutable state; isolation is handled via the `isolation` parameter instead

## Testing

Tests use Swift Testing framework with:
- `actor TestState<T>` for thread-safe mutable state in tests
- `actor OrderTracker` for tracking event ordering
- `AsyncStream` for synchronizing task start/finish signals

Avoid using `confirmation()` for tasks that start asynchronously without awaiting inside the confirmation block.

## Code Style

- Empty line after imports
- Empty lines should have no whitespace
- Never force unwrap or force try
