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

@Suite("TaskStore task naming")
@TestIsolation
struct TaskStoreNameProviderIntegrationTests {

  enum TestKey: Hashable, Sendable {
    case first
  }

  @available(macOS 26.0, iOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *)
  @Test(arguments: AddMethod.available)
  func `tasks are named by the store's provider`(method: AddMethod) async {
    let store = TaskStore<TestKey>(nameProvider: .keyDescription.withPrefix("App"))

    await store.add(method, forKey: .first) {
      #expect(Task.name == "App.first")
    }.value
  }

  @available(macOS 26.0, iOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *)
  @Test(arguments: AddMethod.available)
  func `tasks are unnamed without a provider`(method: AddMethod) async {
    let store = TaskStore<TestKey>()

    await store.add(method, forKey: .first) {
      #expect(Task.name == nil)
    }.value
  }
}
