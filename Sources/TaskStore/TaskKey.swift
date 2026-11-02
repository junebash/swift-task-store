//===----------------------------------------------------------------------===//
//
// This source file is part of the swift-task-store open source project
//
// Copyright (c) June Bash
//
// See LICENSE for license information
//
//===----------------------------------------------------------------------===//

/// A unique task key declared as a property, so a ``TaskStore`` doesn't need a key type.
///
/// Each declared key is distinct from every other key, even ones with the same name.
/// Call a key with an argument to get a separate key per argument.
///
/// ```swift
/// @MainActor
/// final class MyViewModel {
///   let tasks = TaskStore()
///
///   @TaskKey private var loadItems
///   @TaskKey private var loadItem
///
///   func refresh() {
///     tasks.addIsolatedTask(forKey: loadItems) { ... }
///   }
///
///   func itemSelected(_ id: ItemID) {
///     tasks.addIsolatedTask(forKey: loadItem(id)) { ... }
///   }
/// }
/// ```
@propertyWrapper
public struct TaskKey: Hashable, Sendable, CustomStringConvertible {
  private final class Identity: Sendable {}

  private let identity = Identity()
  private let declaration: String
  private var arguments: [any Hashable & Sendable] = []

  /// Creates a new key, described by where it's declared.
  public init(fileID: String = #fileID, line: Int = #line) {
    self.declaration = "\(fileID):\(line)"
  }

  public var wrappedValue: TaskKey { self }

  /// Returns a key for this key and `argument`, distinct for each different argument.
  public func callAsFunction(_ argument: some Hashable & Sendable) -> TaskKey {
    var key = self
    key.arguments.append(argument)
    return key
  }

  public var description: String {
    declaration + arguments.map { "(\($0))" }.joined()
  }

  private var hashableArguments: [AnyHashable] {
    arguments.map { AnyHashable($0) }
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.identity === rhs.identity && lhs.hashableArguments == rhs.hashableArguments
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(ObjectIdentifier(identity))
    hasher.combine(hashableArguments)
  }
}

extension TaskStore where Key == TaskKey {
  /// Creates a new, empty task store keyed by ``TaskKey`` properties.
  public convenience init() {
    self.init(nameProvider: nil)
  }
}
