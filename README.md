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
    .package(url: "https://github.com/junebash/swift-task-store.git", from: "0.1.0")
]
```

## Usage

```swift
import TaskStore

@Observable
@MainActor
final class MyModel {
    let tasks = TaskStore<TaskKey>()

    enum TaskKey: Hashable {
        case fetchUser
        case saveDocument
    }

    func fetchUser() {
        tasks.addTask(forKey: .fetchUser) {
            try? await api.fetchUser()
        }
    }

    var isFetching: Bool {
        tasks.taskIsRunning(forKey: .fetchUser)
    }
}
```

## Duplicate Key Behavior

When adding a task for a key that's already running:

| Behavior | Description |
|----------|-------------|
| `.cancelPrevious(wait: false)` | Cancel previous, start new immediately (default) |
| `.cancelPrevious(wait: true)` | Cancel previous, wait for it, then start new |
| `.wait` | Wait for previous to complete, then start new |
| `.runConcurrently` | Run both tasks simultaneously |
| `.preferPrevious` | Keep existing task, ignore new request |

```swift
// Search: cancel previous searches immediately
tasks.addTask(forKey: .search, duplicateKeyBehavior: .cancelPrevious(wait: false)) {
    await performSearch(query)
}

// Save: wait for previous save to complete
tasks.addTask(forKey: .save, duplicateKeyBehavior: .wait) {
    await saveDocument()
}
```

## API

```swift
// Add a task
@discardableResult
func addTask(
    forKey key: Key,
    duplicateKeyBehavior: TaskStoreDuplicateKeyBehavior = .cancelPrevious(wait: false),
    priority: TaskPriority? = nil,
    operation: @escaping @Sendable () async -> Void
) -> Task<Void, Never>

// Cancel a task
func cancelTask(forKey key: Key)

// Cancel all tasks
func cancelAllTasks()

// Check if a task is running
func taskIsRunning(forKey key: Key) -> Bool

// Running task info
var runningTaskCount: Int
var runningTaskKeys: Set<Key>
```

## License

MIT
