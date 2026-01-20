//===----------------------------------------------------------------------===//
//
// This source file is part of the swift-task-store open source project
//
// Copyright (c) June Bash
//
// See LICENSE for license information
//
//===----------------------------------------------------------------------===//

/// A type that provides names for tasks based on their keys.
///
/// Task name providers determine how tasks are named in debugging and instrumentation contexts.
/// This follows a similar pattern to SwiftUI's style types (like `ButtonStyle`), where you can
/// use built-in providers or create custom ones.
///
/// ## Built-in Providers
///
/// The library provides several built-in name providers:
///
/// - ``NoneTaskNameProvider``: Returns `nil` for all keys (no task naming).
/// - ``KeyDescriptionTaskNameProvider``: Uses `String(describing:)` on the key.
/// - ``ConstantTaskNameProvider``: Returns the same name for all keys.
/// - ``FromKeyTaskNameProvider``: Uses a custom closure to generate names.
///
/// ## Example Usage
///
/// ```swift
/// // Use key description as task names
/// let store = TaskStore<MyKey>(nameProvider: .keyDescription)
///
/// // Use a constant name
/// let store = TaskStore<MyKey>(nameProvider: .constant("MyTask"))
///
/// // Use a custom closure
/// let store = TaskStore<MyKey>(nameProvider: .fromKey { key in
///     "Task-\(key)"
/// })
///
/// // Add a prefix to any provider
/// let store = TaskStore<MyKey>(nameProvider: .keyDescription.withPrefix("CounterViewModel"))
/// ```
public protocol TaskNameProvider<Key> {
  /// The type of key this provider generates names for.
  associatedtype Key

  /// Returns a task name for the given key.
  ///
  /// - Parameter key: The key identifying the task.
  /// - Returns: A task name, or `nil` if no name should be used.
  func name(forKey key: Key) -> String?
}

extension TaskNameProvider {
  /// Calls the provider with the given key.
  ///
  /// This is a convenience method equivalent to calling ``name(forKey:)``.
  @inlinable
  public func callAsFunction(_ key: Key) -> String? {
    name(forKey: key)
  }
}

// MARK: - Static Convenience Accessors

extension TaskNameProvider {
  /// A provider that uses `String(describing:)` on the key.
  @inlinable
  public static func keyDescription<Key>() -> Self
  where Self == KeyDescriptionTaskNameProvider<Key> {
    Self()
  }

  /// Creates a provider that returns a constant name for all keys.
  ///
  /// - Parameter name: The name to return, or `nil` for no name.
  @inlinable
  public static func constant<Key>(_ name: String?) -> Self
  where Self == ConstantTaskNameProvider<Key> {
    Self(name)
  }

  /// Creates a provider using a custom closure.
  ///
  /// - Parameter nameFromKey: A closure that generates names from keys.
  @inlinable
  public static func fromKey<Key>(
    _ nameFromKey: @escaping (Key) -> String?
  ) -> Self where Self == FromKeyTaskNameProvider<Key> {
    Self(nameFromKey)
  }
}

// MARK: - Provider Modifiers

extension TaskNameProvider {
  /// Returns a provider that adds a prefix to this provider's names.
  ///
  /// - Parameters:
  ///   - prefix: The prefix to prepend.
  ///   - separator: The separator between prefix and name. Defaults to `"."`.
  /// - Returns: A new provider that prepends the prefix to names.
  ///
  /// ```swift
  /// let provider = KeyDescriptionTaskNameProvider<MyKey>().withPrefix("App")
  /// // Or using static accessor:
  /// let provider: some TaskNameProvider<MyKey> = .keyDescription.withPrefix("App")
  /// ```
  @inlinable
  public func withPrefix(
    _ prefix: String,
    separator: String = "."
  ) -> PrefixedTaskNameProvider<Self> {
    PrefixedTaskNameProvider(base: self, prefix: prefix, separator: separator)
  }

  /// Returns a provider that appends incrementing suffixes to this provider's names.
  ///
  /// - Parameter separator: The separator between name and suffix. Defaults to `"."`.
  /// - Returns: A new provider that appends incrementing numbers to names.
  ///
  /// ```swift
  /// let provider = KeyDescriptionTaskNameProvider<MyKey>().withIncrementingSuffix()
  /// ```
  @inlinable
  public func withIncrementingSuffix(
    separator: String = "."
  ) -> IncrementingSuffixTaskNameProvider<Self> {
    IncrementingSuffixTaskNameProvider(base: self, separator: separator)
  }
}

// MARK: - Built-in Provider Definitions

/// A task name provider that uses `String(describing:)` on the key.
///
/// This provider generates task names by converting the key to its string description.
/// This is useful when your keys are enums or types with meaningful `description` values.
///
/// ```swift
/// enum TaskKey { case fetchUser, saveDocument }
/// let store = TaskStore<TaskKey>(nameProvider: .keyDescription)
/// // Task for .fetchUser would be named "fetchUser"
/// ```
public struct KeyDescriptionTaskNameProvider<Key>: TaskNameProvider {
  @inlinable
  init() {}

  @inlinable
  public func name(forKey key: Key) -> String? {
    String(describing: key)
  }
}

/// A task name provider that returns the same name for all keys.
///
/// Use this provider when all tasks should share the same name, regardless of their key.
///
/// ```swift
/// let store = TaskStore<MyKey>(nameProvider: .constant("BackgroundTask"))
/// ```
public struct ConstantTaskNameProvider<Key>: TaskNameProvider {
  @usableFromInline
  let name: String?

  /// Creates a constant name provider.
  ///
  /// - Parameter name: The name to return for all keys, or `nil` for no name.
  @inlinable
  init(_ name: String?) {
    self.name = name
  }

  @inlinable
  public func name(forKey key: Key) -> String? {
    name
  }
}

/// A task name provider that uses a closure to generate names.
///
/// This is the most flexible provider, allowing arbitrary logic to determine task names.
///
/// ```swift
/// let store = TaskStore<Int>(nameProvider: .fromKey { key in
///     "Task-\(key)"
/// })
/// ```
public struct FromKeyTaskNameProvider<Key>: TaskNameProvider {
  @usableFromInline
  let nameFromKey: (Key) -> String?

  /// Creates a provider with a custom name-generating closure.
  ///
  /// - Parameter nameFromKey: A closure that takes a key and returns a task name.
  @inlinable
  init(_ nameFromKey: @escaping (Key) -> String?) {
    self.nameFromKey = nameFromKey
  }

  @inlinable
  public func name(forKey key: Key) -> String? {
    nameFromKey(key)
  }
}

/// A task name provider that adds a prefix to names from another provider.
///
/// This provider wraps another provider and prepends a prefix string to any
/// non-nil names it produces.
///
/// ```swift
/// let store = TaskStore<MyKey>(nameProvider: .keyDescription.withPrefix("App"))
/// // Task for .fetchUser would be named "App.fetchUser"
/// ```
public struct PrefixedTaskNameProvider<Base: TaskNameProvider>: TaskNameProvider {
  public typealias Key = Base.Key

  @usableFromInline
  let base: Base

  @usableFromInline
  let prefix: String

  @usableFromInline
  let separator: String

  /// Creates a prefixed name provider.
  ///
  /// - Parameters:
  ///   - base: The underlying provider to wrap.
  ///   - prefix: The prefix to prepend to names.
  ///   - separator: The separator between prefix and name. Defaults to `"."`.
  @inlinable
  init(base: Base, prefix: String, separator: String = ".") {
    self.base = base
    self.prefix = prefix
    self.separator = separator
  }

  @inlinable
  public func name(forKey key: Key) -> String? {
    guard let baseName = base.name(forKey: key) else {
      return nil
    }
    return "\(prefix)\(separator)\(baseName)"
  }
}

/// A task name provider that appends an incrementing suffix to names.
///
/// Each time a name is generated, it includes a unique incrementing number.
/// This is useful for distinguishing between multiple tasks with the same key.
///
/// ```swift
/// let store = TaskStore<MyKey>(nameProvider: .keyDescription.withIncrementingSuffix())
/// // First task for .fetchUser: "fetchUser.0"
/// // Second task for .fetchUser: "fetchUser.1"
/// ```
public final class IncrementingSuffixTaskNameProvider<Base: TaskNameProvider>: TaskNameProvider {
  public typealias Key = Base.Key

  @usableFromInline
  let base: Base

  @usableFromInline
  let separator: String

  @usableFromInline
  var counter: UInt64 = 0

  /// Creates an incrementing suffix provider.
  ///
  /// - Parameters:
  ///   - base: The underlying provider to wrap.
  ///   - separator: The separator between name and suffix. Defaults to `"."`.
  @inlinable
  init(base: Base, separator: String = ".") {
    self.base = base
    self.separator = separator
  }

  @inlinable
  public func name(forKey key: Key) -> String? {
    defer { counter &+= 1 }
    if let baseName = base.name(forKey: key) {
      return "\(baseName)\(separator)\(counter)"
    } else {
      return String(counter)
    }
  }
}
