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
/// Declare each key as a `@TaskKey` property of a class, and create the store with
/// `TaskStore()`. Calling a key with a `Hashable & Sendable` argument returns a separate
/// key per argument.
///
/// ```swift
/// @Observable
/// @MainActor
/// final class ItemsModel {
///   let tasks = TaskStore()
///
///   @ObservationIgnored @TaskKey private var loadItemsKey
///   @ObservationIgnored @TaskKey private var loadItemKey
///
///   func loadItems() {
///     tasks.addIsolatedTask(forKey: loadItemsKey) { ... }
///   }
///
///   func itemSelected(_ id: Item.ID) {
///     tasks.addIsolatedTask(forKey: loadItemKey(id)) { ... }
///   }
/// }
/// ```
///
/// Every declared key is distinct, including the same property on different instances.
/// A key describes itself by its property and arguments, such as `ItemsModel.loadItemKey(42)`,
/// so ``TaskNameProvider/keyDescription`` names its tasks after it.
///
/// `@TaskKey` is only available on properties of classes. In an `@Observable` class,
/// mark keys `@ObservationIgnored`, as with any property wrapper.
@propertyWrapper
public struct TaskKey: Hashable, Sendable, CustomStringConvertible {
  private final class Identity: Sendable {}

  private let identity = Identity()
  private var name = ""
  private var arguments: [any Hashable & Sendable] = []

  public init() {}

  @available(*, unavailable, message: "@TaskKey is only available on properties of classes")
  public var wrappedValue: TaskKey { self }

  /// Names the key after its property, such as `MyViewModel.loadItems`.
  public static subscript<EnclosingSelf: AnyObject>(
    _enclosingInstance instance: EnclosingSelf,
    wrapped wrappedKeyPath: KeyPath<EnclosingSelf, TaskKey>,
    storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, TaskKey>
  ) -> TaskKey {
    var key = instance[keyPath: storageKeyPath]
    key.name = String(String(describing: wrappedKeyPath).trimmingPrefix("\\"))
    return key
  }

  /// Returns a key for this key and `argument`, distinct for each different argument.
  public func callAsFunction(_ argument: some Hashable & Sendable) -> TaskKey {
    var key = self
    key.arguments.append(argument)
    return key
  }

  public var description: String {
    name + arguments.map { "(\($0))" }.joined()
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
