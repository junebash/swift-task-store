# swift-task-store Releases

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
