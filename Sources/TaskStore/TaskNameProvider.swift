//===----------------------------------------------------------------------===//
//
// This source file is part of the swift-task-store open source project
//
// Copyright (c) June Bash
//
// See LICENSE for license information
//
//===----------------------------------------------------------------------===//

/// Names the tasks a ``TaskStore`` creates, for debugging and instrumentation.
///
/// Start from a built-in provider and adjust it with modifiers:
///
/// - ``keyDescription``: Uses `String(describing:)` on the key.
/// - ``constant(_:)``: Uses the same name for every key.
/// - ``fromKey(_:)``: Uses a custom closure.
/// - ``withPrefix(_:separator:)``: Prepends a prefix to each name.
/// - ``withIncrementingSuffix(separator:)``: Appends a number that goes up with each task named.
///
/// Modifiers only change names that exist; a key the base provider leaves unnamed stays unnamed.
///
/// ```swift
/// let store = TaskStore<MyKey>(nameProvider: .keyDescription.withPrefix("MyViewModel"))
/// // A task for .fetchUser is named "MyViewModel.fetchUser"
/// ```
public struct TaskNameProvider<Key> {
  private let makeName: (Key) -> String?

  private init(_ makeName: @escaping (Key) -> String?) {
    self.makeName = makeName
  }

  /// Returns the name for a task with the given key, or `nil` for no name.
  public func name(forKey key: Key) -> String? {
    makeName(key)
  }

  /// Names each task with `String(describing:)` of its key.
  public static var keyDescription: Self {
    Self { String(describing: $0) }
  }

  /// Gives every task the same name, or no name if `name` is `nil`.
  public static func constant(_ name: String?) -> Self {
    Self { _ in name }
  }

  /// Names each task with the result of `name`, or no name where it returns `nil`.
  public static func fromKey(_ name: @escaping (Key) -> String?) -> Self {
    Self(name)
  }

  /// Prepends `prefix` and `separator` to each name.
  public func withPrefix(_ prefix: String, separator: String = ".") -> Self {
    Self { key in
      name(forKey: key).map { "\(prefix)\(separator)\($0)" }
    }
  }

  /// Appends `separator` and a number to each name.
  ///
  /// The number starts at 0 and goes up by one for each task named, across all keys.
  public func withIncrementingSuffix(separator: String = ".") -> Self {
    let counter = Counter()
    return Self { key in
      guard let name = name(forKey: key) else { return nil }
      defer { counter.value &+= 1 }
      return "\(name)\(separator)\(counter.value)"
    }
  }
}

private final class Counter {
  var value: UInt64 = 0
}
