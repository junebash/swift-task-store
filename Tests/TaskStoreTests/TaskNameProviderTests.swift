//===----------------------------------------------------------------------===//
//
// This source file is part of the swift-task-store open source project
//
// Copyright (c) June Bash
//
// See LICENSE for license information
//
//===----------------------------------------------------------------------===//

import Testing
import TaskStore

@Suite("TaskNameProvider Tests")
struct TaskNameProviderTests {

  enum TestKey: Hashable, Sendable, CustomStringConvertible {
    case fetchUser
    case saveDocument
    case uploadImage

    var description: String {
      switch self {
      case .fetchUser: "fetchUser"
      case .saveDocument: "saveDocument"
      case .uploadImage: "uploadImage"
      }
    }
  }

  // MARK: - KeyDescriptionTaskNameProvider

  @Test
  func `keyDescription provider returns string describing key`() {
    let provider: KeyDescriptionTaskNameProvider<TestKey> = .keyDescription()

    #expect(provider.name(forKey: .fetchUser) == "fetchUser")
    #expect(provider.name(forKey: .saveDocument) == "saveDocument")
    #expect(provider.name(forKey: .uploadImage) == "uploadImage")
  }

  @Test
  func `keyDescription provider via static accessor`() {
    let provider: KeyDescriptionTaskNameProvider<TestKey> = .keyDescription()

    #expect(provider.name(forKey: .fetchUser) == "fetchUser")
  }

  @Test
  func `keyDescription provider with Int keys`() {
    let provider: KeyDescriptionTaskNameProvider<Int> = .keyDescription()

    #expect(provider.name(forKey: 42) == "42")
    #expect(provider.name(forKey: 0) == "0")
    #expect(provider.name(forKey: -1) == "-1")
  }

  // MARK: - ConstantTaskNameProvider

  @Test
  func `constant provider returns same name for all keys`() {
    let provider: ConstantTaskNameProvider<TestKey> = .constant("BackgroundTask")

    #expect(provider.name(forKey: .fetchUser) == "BackgroundTask")
    #expect(provider.name(forKey: .saveDocument) == "BackgroundTask")
    #expect(provider.name(forKey: .uploadImage) == "BackgroundTask")
  }

  @Test
  func `constant provider with nil returns nil`() {
    let provider: ConstantTaskNameProvider<TestKey> = .constant(nil)

    #expect(provider.name(forKey: .fetchUser) == nil)
  }

  // MARK: - FromKeyTaskNameProvider

  @Test
  func `fromKey provider uses closure for name generation`() {
    let provider: some TaskNameProvider<TestKey> = .fromKey { key in
      "Task-\(key)"
    }

    #expect(provider.name(forKey: .fetchUser) == "Task-fetchUser")
    #expect(provider.name(forKey: .saveDocument) == "Task-saveDocument")
  }

  @Test
  func `fromKey provider can return nil`() {
    let provider: FromKeyTaskNameProvider<TestKey> = .fromKey { key in
      key == .fetchUser ? "FetchTask" : nil
    }

    #expect(provider.name(forKey: .fetchUser) == "FetchTask")
    #expect(provider.name(forKey: .saveDocument) == nil)
  }

  // MARK: - PrefixedTaskNameProvider

  @Test
  func `prefixed provider adds prefix with default separator`() {
    let provider: KeyDescriptionTaskNameProvider<TestKey> = .keyDescription()
    let prefixed = provider.withPrefix("MyApp")

    #expect(prefixed.name(forKey: .fetchUser) == "MyApp.fetchUser")
    #expect(prefixed.name(forKey: .saveDocument) == "MyApp.saveDocument")
  }

  @Test
  func `prefixed provider uses custom separator`() {
    let provider: KeyDescriptionTaskNameProvider<TestKey> = .keyDescription()
    let prefixed = provider.withPrefix("App", separator: "-")

    #expect(prefixed.name(forKey: .fetchUser) == "App-fetchUser")
  }

  @Test
  func `prefixed provider returns nil when base returns nil`() {
    let provider: ConstantTaskNameProvider<TestKey> = .constant(nil)
    let prefixed = provider.withPrefix("MyApp")

    #expect(prefixed.name(forKey: .fetchUser) == nil)
  }

  @Test
  func `withPrefix modifier with custom separator`() {
    let provider: KeyDescriptionTaskNameProvider<TestKey> = .keyDescription()
    let prefixed = provider.withPrefix("App", separator: "::")

    #expect(prefixed.name(forKey: .fetchUser) == "App::fetchUser")
  }

  // MARK: - IncrementingSuffixTaskNameProvider

  @Test
  func `incrementing suffix provider adds incrementing numbers`() {
    let provider: KeyDescriptionTaskNameProvider<TestKey> = .keyDescription()
    let incrementing = provider.withIncrementingSuffix()

    #expect(incrementing.name(forKey: .fetchUser) == "fetchUser.0")
    #expect(incrementing.name(forKey: .fetchUser) == "fetchUser.1")
    #expect(incrementing.name(forKey: .saveDocument) == "saveDocument.2")
    #expect(incrementing.name(forKey: .fetchUser) == "fetchUser.3")
  }

  @Test
  func `incrementing suffix provider uses custom separator`() {
    let provider: KeyDescriptionTaskNameProvider<TestKey> = .keyDescription()
    let incrementing = provider.withIncrementingSuffix(separator: "#")

    #expect(incrementing.name(forKey: .fetchUser) == "fetchUser#0")
    #expect(incrementing.name(forKey: .fetchUser) == "fetchUser#1")
  }

  @Test
  func `incrementing suffix provider with nil base returns number only`() {
    let provider: ConstantTaskNameProvider<TestKey> = .constant(nil)
    let incrementing = provider.withIncrementingSuffix()

    #expect(incrementing.name(forKey: .fetchUser) == "0")
    #expect(incrementing.name(forKey: .fetchUser) == "1")
    #expect(incrementing.name(forKey: .saveDocument) == "2")
  }

  // MARK: - callAsFunction

  @Test
  func `callAsFunction is equivalent to name(forKey:)`() {
    let provider: KeyDescriptionTaskNameProvider<TestKey> = .keyDescription()

    #expect(provider(.fetchUser) == provider.name(forKey: .fetchUser))
    #expect(provider(.fetchUser) == "fetchUser")
  }

  // MARK: - Chaining

  @Test
  func `providers can be chained with prefix and suffix`() {
    let provider: KeyDescriptionTaskNameProvider<TestKey> = .keyDescription()
    let chained = provider.withPrefix("App").withIncrementingSuffix()

    #expect(chained.name(forKey: .fetchUser) == "App.fetchUser.0")
    #expect(chained.name(forKey: .saveDocument) == "App.saveDocument.1")
  }

  @Test
  func `providers can be chained with suffix and prefix`() {
    let provider: KeyDescriptionTaskNameProvider<TestKey> = .keyDescription()
    let chained = provider.withIncrementingSuffix().withPrefix("App")

    #expect(chained.name(forKey: .fetchUser) == "App.fetchUser.0")
    #expect(chained.name(forKey: .saveDocument) == "App.saveDocument.1")
  }
}
