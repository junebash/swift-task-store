# swift-task-store Releases

## v0.2.0

## Breaking Changes

- `Task+CancellableValue` extension has been removed (not needed; use PointFree's `swift-concurrency-extras` library)

## Features

- `addConcurrentTask(key:duplicateKeyBehavior:operation:)` - Runs task on global concurrent executor while still propagating `TaskLocal` values
- `addIsolatedTask(key:duplicateKeyBehavior:operation:)` - Inherits caller's actor isolation (like `Task.init`)

## Deprecations

- `addTask` is deprecated in favor of `addConcurrentTask`

---

## v0.1.0

Initial release.

### Features

- `TaskStore<Key>` - Observable container for managing keyed async tasks
- `TaskStoreDuplicateKeyBehavior` - Configurable handling for duplicate key requests:
  - `.cancelPrevious(wait:)` - Cancel and optionally wait for previous task
  - `.wait` - Wait for previous task to complete before starting new one
  - `.runConcurrently` - Run both tasks simultaneously
  - `.preferPrevious` - Keep existing task, ignore new request

---

## v0.1.0

Initial release.

### Features

- `TaskStore<Key>` - Observable container for managing keyed async tasks
- `TaskStoreDuplicateKeyBehavior` - Configurable handling for duplicate key requests:
  - `.cancelPrevious(wait:)` - Cancel and optionally wait for previous task
  - `.wait` - Wait for previous task to complete before starting new one
  - `.runConcurrently` - Run both tasks simultaneously
  - `.preferPrevious` - Keep existing task, ignore new request
- `Task+CancellableValue` - Extension for propagating cancellation when awaiting task values

---
