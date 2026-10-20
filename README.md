# TaskStore

A Swift 6 library for managing concurrent async tasks by key, with configurable behavior for duplicate requests.

## Background

- [Task Management in Swift Part 1: The Problem](https://www.junebash.com/posts/task-management-in-swift-part-1-the-problem/)
- [Task Management in Swift Part 2: Introducing the TaskStore](https://www.junebash.com/posts/task-management-in-swift-part-2-introducing-the/)
- [Task Management in Swift Part 3: Duplicate Key Behavior](https://www.junebash.com/posts/task-management-in-swift-part-3-duplicate-key/)

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/junebash/swift-task-store.git", from: "0.4.0")
]
```

## Usage

> **Note:** `TaskStore` must be used from an isolated context (e.g., `@MainActor` or a custom actor). The compiler enforces this.

```swift
import TaskStore

@Observable
@MainActor
final class MyModel {
    let tasks = TaskStore<TaskKey>()
    var user: User?

    enum TaskKey: Hashable {
        case fetchUser
        case processData
    }

    func fetchUser() {
        // Inherits MainActor isolation
        tasks.addIsolatedTask(forKey: .fetchUser) {
            self.user = try? await api.fetchUser()
        }
    }

    func processInBackground() {
        // Runs on the global concurrent executor
        tasks.addConcurrentTask(forKey: .processData) {
            await heavyComputation()
        }
    }

    var isFetching: Bool {
        tasks.taskIsRunning(forKey: .fetchUser)
    }
}
```

Operations must write `self.` explicitly, so it's visible when a task keeps its owner alive.

When the store is released, for example along with the model that owns it, all of its tasks are cancelled.

## Duplicate Key Behavior

Each key has at most one current task. When adding a task for a key that already has one:

| Behavior | Description |
|----------|-------------|
| `.cancelPrevious(wait: false)` | Cancel previous, start new immediately (default) |
| `.cancelPrevious(wait: true)` | Cancel previous, wait for it, then start new |
| `.wait` | Wait for previous to complete, then start new |
| `.runConcurrently` | Run both tasks simultaneously |
| `.preferPrevious` | Keep existing task, ignore new request (unless it was cancelled) |

Except with `.preferPrevious`, the new task becomes the key's current task, and the task it replaced is no longer tracked. While the current task is running, cancelling it also cancels the tasks it replaced.

If a task is cancelled before its operation starts, for example while waiting for the previous task, the operation doesn't run.

```swift
// Search: cancel previous searches immediately
tasks.addConcurrentTask(forKey: .search, duplicateKeyBehavior: .cancelPrevious(wait: false)) {
    await performSearch(query)
}

// Save: wait for previous save to complete
tasks.addIsolatedTask(forKey: .save, duplicateKeyBehavior: .wait) {
    await self.saveDocument()
}
```

## Task Naming

`TaskStore` supports optional task naming for debugging and instrumentation via `TaskNameProvider`:

```swift
// Use key description as task names
let store = TaskStore<TaskKey>(nameProvider: .keyDescription)

// Use a constant name
let store = TaskStore<TaskKey>(nameProvider: .constant("BackgroundTask"))

// Use a custom closure
let store = TaskStore<TaskKey>(nameProvider: .fromKey { key in
    "Task-\(key)"
})

// Compose with modifiers
let store = TaskStore<TaskKey>(
    nameProvider: .keyDescription
        .withPrefix("MyViewModel")
        .withIncrementingSuffix()
)
// Produces: "MyViewModel.fetchUser.0", "MyViewModel.saveDocument.1", etc.
```

The name can be accessed from within the task via `Task.name`.

| Provider | Description |
|----------|-------------|
| `.keyDescription` | Uses `String(describing:)` on the key |
| `.constant("name")` | Returns the same name for all keys |
| `.fromKey { ... }` | Uses a custom closure to generate names |

| Modifier | Description |
|----------|-------------|
| `.withPrefix("prefix")` | Prepends a prefix (e.g., `"App.fetchUser"`) |
| `.withIncrementingSuffix()` | Appends a number that goes up with each task named, across all keys (e.g., `"fetchUser.0"`) |

Modifiers leave unnamed tasks unnamed.

## API

```swift
init(nameProvider: TaskNameProvider<Key>? = nil)

// Add a task that runs on the global concurrent executor
@discardableResult
func addConcurrentTask(
    forKey key: Key,
    duplicateKeyBehavior: TaskStoreDuplicateKeyBehavior = .cancelPrevious(wait: false),
    priority: TaskPriority? = nil,
    operation: @escaping @Sendable () async -> Void
) -> Task<Void, Never>

// Add a task that inherits the caller's actor isolation
@discardableResult
func addIsolatedTask(
    forKey key: Key,
    duplicateKeyBehavior: TaskStoreDuplicateKeyBehavior = .cancelPrevious(wait: false),
    priority: TaskPriority? = nil,
    operation: @escaping () async -> Void
) -> Task<Void, Never>

// Add a task with immediate execution (Swift 6.2+, SE-0472)
// Runs synchronously until first suspension point, then continues asynchronously
@available(macOS 26.0, iOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *)
@discardableResult
func addImmediateTask(
    forKey key: Key,
    duplicateKeyBehavior: TaskStoreDuplicateKeyBehavior = .cancelPrevious(wait: false),
    priority: TaskPriority? = nil,
    operation: @escaping () async -> Void
) -> Task<Void, Never>

// Cancel a key's current task (and the tasks it replaced, if still running)
func cancelTask(forKey key: Key)

// Cancel all tasks
func cancelAllTasks()

// Check if a key has a current task
func taskIsRunning(forKey key: Key) -> Bool

// Get the current task for a key
func currentTask(forKey key: Key) -> Task<Void, Never>?

// Keys with a current task
var runningTaskCount: Int
var runningTaskKeys: Set<Key>
```

## License

MIT
