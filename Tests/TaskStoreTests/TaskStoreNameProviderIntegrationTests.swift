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

@Suite("TaskStore NameProvider Integration Tests")
@TestIsolation
struct TaskStoreNameProviderIntegrationTests {

  enum TestKey: Hashable, Sendable {
    case first
    case second
  }

  @Test
  func `TaskStore uses keyDescription nameProvider`() {
    let provider: KeyDescriptionTaskNameProvider<TestKey> = .keyDescription()
    let store = TaskStore<TestKey>(nameProvider: provider)

    // Verify the store was created with the provider
    #expect(store.runningTaskCount == 0)
  }

  @Test
  func `TaskStore uses constant nameProvider`() {
    let provider: ConstantTaskNameProvider<TestKey> = .constant("MyTask")
    let store = TaskStore<TestKey>(nameProvider: provider)

    #expect(store.runningTaskCount == 0)
  }

  @Test
  func `TaskStore uses prefixed nameProvider`() {
    let provider: KeyDescriptionTaskNameProvider<TestKey> = .keyDescription()
    let store = TaskStore<TestKey>(nameProvider: provider.withPrefix("App"))

    #expect(store.runningTaskCount == 0)
  }

  @Test
  func `TaskStore nameProvider can be changed after init`() {
    let store = TaskStore<TestKey>()

    // Default is nil
    #expect(store.nameProvider == nil)

    let provider: KeyDescriptionTaskNameProvider<TestKey> = .keyDescription()
    store.nameProvider = provider
    #expect(store.nameProvider != nil)
  }

  @Test
  func `TaskStore with nil nameProvider`() {
    let store = TaskStore<TestKey>(
      nameProvider: nil as KeyDescriptionTaskNameProvider<TestKey>?
    )

    #expect(store.nameProvider == nil)
    #expect(store.runningTaskCount == 0)
  }

  @available(macOS 26.0, iOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *)
  @Test
  @MainActor
  func `addConcurrentTask uses nameProvider`() async {
    let provider: KeyDescriptionTaskNameProvider<TestKey> = .keyDescription()
    let store = TaskStore<TestKey>(nameProvider: provider)

    await store.addConcurrentTask(forKey: TestKey.first) {
      #expect(Task.name == "first")
    }.value
  }

  @available(macOS 26.0, iOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *)
  @Test
  @MainActor
  func `addIsolatedTask uses nameProvider`() async {
    let provider: KeyDescriptionTaskNameProvider<TestKey> = .keyDescription()
    let store = TaskStore<TestKey>(nameProvider: provider)

    await store.addIsolatedTask(forKey: TestKey.first) {
      #expect(Task.name == "first")
    }.value
  }

  @available(macOS 26.0, iOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *)
  @Test
  @MainActor
  func `addImmediateTask uses nameProvider`() async {
    let provider: KeyDescriptionTaskNameProvider<TestKey> = .keyDescription()
    let store = TaskStore<TestKey>(nameProvider: provider)

    await store.addImmediateTask(forKey: TestKey.first) {
      #expect(Task.name == "first")
    }.value
  }

  @available(macOS 26.0, iOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *)
  @Test
  @MainActor
  func `task has no name when nameProvider is nil`() async {
    let store = TaskStore<TestKey>()

    await store.addConcurrentTask(forKey: TestKey.first) {
      #expect(Task.name == nil)
    }.value
  }

  @available(macOS 26.0, iOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *)
  @Test
  @MainActor
  func `task name uses prefixed provider`() async {
    let provider: KeyDescriptionTaskNameProvider<TestKey> = .keyDescription()
    let store = TaskStore<TestKey>(nameProvider: provider.withPrefix("MyApp"))

    await store.addConcurrentTask(forKey: TestKey.first) {
      #expect(Task.name == "MyApp.first")
    }.value
  }
}
