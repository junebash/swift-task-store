# swift-task-store Releases

## v1.0.0

### Breaking Changes

- Releasing a `TaskStore` now cancels its running tasks. Tasks no longer keep the store alive, so keep a reference to the store for as long as its tasks should run.
- `addIsolatedTask` and `addImmediateTask` operations must write `self.` explicitly (`@_implicitSelfCapture` was removed), so it's visible when a task keeps its owner alive.
- `TaskNameProvider` is now a struct instead of a protocol, and the separate provider types and `callAsFunction` are gone
  - Use `.keyDescription` (no parentheses), `.constant(_:)`, `.fromKey { ... }`, `.withPrefix(_:)` and `.withIncrementingSuffix()`
  - `TaskStore` has a single `init(nameProvider:)` that defaults to `nil`
  - `.withIncrementingSuffix()` leaves unnamed tasks unnamed instead of naming them with just a number
- The `preferPrevious`, `cancelPrevious`, `waitForPrevious` and `runNewTask` instance properties on `TaskStoreDuplicateKeyBehavior` are no longer public.

### Features

- An operation whose task is cancelled before it starts no longer runs, for example when a task waiting under `.wait` or `.cancelPrevious(wait: true)` is replaced before its turn.

### Bug Fixes

- The documented name-provider syntax now compiles, e.g. `TaskStore<Key>(nameProvider: .keyDescription.withPrefix("App"))`.
- `addIsolatedTask` now always runs its operation on the caller's actor, including when called from a function that takes an `isolated` parameter.

### Improvements

- Documented the one-current-task-per-key model, how cancelling the current task also cancels the tasks it replaced, and that `.preferPrevious` returns the current task even after it was cancelled.
- CI now runs on macOS 26 (Swift 6.2), and the release workflow runs the tests first.

---

## v0.4.0

### Features

- `TaskNameProvider` protocol for customizable task naming
  - Built-in providers: `.keyDescription`, `.constant("name")`, `.fromKey { ... }`
  - Composable modifiers: `.withPrefix("prefix")`, `.withIncrementingSuffix()`
  - `TaskStore` now accepts an optional `nameProvider` parameter for all task creation methods

---

## v0.3.0

### Features

- `addImmediateTask(key:duplicateKeyBehavior:operation:)` - Uses `Task.immediate` (Swift 6.2+, SE-0472) to start tasks synchronously on the caller's execution context until the first suspension point

---

## v0.2.0

### Breaking Changes

- `Task+CancellableValue` extension has been removed (not needed; use PointFree's `swift-concurrency-extras` library)

### Features

- `addConcurrentTask(key:duplicateKeyBehavior:operation:)` - Runs task on global concurrent executor while still propagating `TaskLocal` values
- `addIsolatedTask(key:duplicateKeyBehavior:operation:)` - Inherits caller's actor isolation (like `Task.init`)

### Deprecations

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
