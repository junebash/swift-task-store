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

@Suite("TaskNameProvider")
struct TaskNameProviderTests {

  enum TestKey: Hashable, Sendable {
    case fetchUser
    case saveDocument
  }

  @Test
  func `keyDescription names tasks after their key`() {
    let provider: TaskNameProvider<TestKey> = .keyDescription

    #expect(provider.name(forKey: .fetchUser) == "fetchUser")
    #expect(provider.name(forKey: .saveDocument) == "saveDocument")
  }

  @Test
  func `constant gives every task the same name`() {
    let provider: TaskNameProvider<TestKey> = .constant("Background")

    #expect(provider.name(forKey: .fetchUser) == "Background")
    #expect(provider.name(forKey: .saveDocument) == "Background")
  }

  @Test
  func `fromKey names tasks with the closure's result`() {
    let provider: TaskNameProvider<TestKey> = .fromKey { key in
      key == .fetchUser ? "Fetch" : nil
    }

    #expect(provider.name(forKey: .fetchUser) == "Fetch")
    #expect(provider.name(forKey: .saveDocument) == nil)
  }

  @Test
  func `withPrefix prepends the prefix and separator`() {
    let provider: TaskNameProvider<TestKey> = .keyDescription.withPrefix("App")
    let custom: TaskNameProvider<TestKey> = .keyDescription.withPrefix("App", separator: "::")

    #expect(provider.name(forKey: .fetchUser) == "App.fetchUser")
    #expect(custom.name(forKey: .fetchUser) == "App::fetchUser")
  }

  @Test
  func `withIncrementingSuffix numbers tasks across all keys`() {
    let provider: TaskNameProvider<TestKey> = .keyDescription.withIncrementingSuffix()

    #expect(provider.name(forKey: .fetchUser) == "fetchUser.0")
    #expect(provider.name(forKey: .fetchUser) == "fetchUser.1")
    #expect(provider.name(forKey: .saveDocument) == "saveDocument.2")
  }

  @Test
  func `withIncrementingSuffix uses the separator`() {
    let provider: TaskNameProvider<TestKey> = .keyDescription.withIncrementingSuffix(separator: "#")

    #expect(provider.name(forKey: .fetchUser) == "fetchUser#0")
  }

  @Test
  func `modifiers leave unnamed tasks unnamed`() {
    let base: TaskNameProvider<TestKey> = .fromKey { key in
      key == .fetchUser ? "fetchUser" : nil
    }
    let provider = base.withPrefix("App").withIncrementingSuffix()

    #expect(provider.name(forKey: .saveDocument) == nil)
    #expect(provider.name(forKey: .fetchUser) == "App.fetchUser.0")
  }

  @Test
  func `suffix applies to the prefixed name regardless of order`() {
    let prefixFirst: TaskNameProvider<TestKey> = .keyDescription.withPrefix("App").withIncrementingSuffix()
    let suffixFirst: TaskNameProvider<TestKey> = .keyDescription.withIncrementingSuffix().withPrefix("App")

    #expect(prefixFirst.name(forKey: .fetchUser) == "App.fetchUser.0")
    #expect(suffixFirst.name(forKey: .fetchUser) == "App.fetchUser.0")
  }
}
