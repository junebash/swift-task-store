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

@Suite("TaskKey", .timeLimit(.minutes(1)))
@TestIsolation
struct TaskKeyTests {

  final class Model {
    let tasks = TaskStore()

    @TaskKey var loadItems
    @TaskKey var loadItem
  }

  @Test
  func `keys are distinct per declaration and per instance`() {
    let model = Model()
    let other = Model()

    #expect(model.loadItems == model.loadItems)
    #expect(model.loadItems != model.loadItem)
    #expect(model.loadItems != other.loadItems)
  }

  @Test
  func `calling a key with an argument makes a key per argument`() {
    let model = Model()

    #expect(model.loadItem(1) == model.loadItem(1))
    #expect(model.loadItem(1) != model.loadItem(2))
    #expect(model.loadItem(1) != model.loadItem)
    #expect(model.loadItem(1) != model.loadItem("1"))
    #expect(model.loadItem(1)(2) != model.loadItem(2)(1))
  }

  @Test
  func `keys are described by their property and arguments`() {
    let model = Model()

    #expect(model.loadItems.description == "Model.loadItems")
    #expect(model.loadItem(1)("a").description == "Model.loadItem(1)(a)")
  }

  @Test
  func `a key's new task cancels its previous one but not other keys' tasks`() async {
    let model = Model()
    let release = Gate()

    let first = model.tasks.addIsolatedTask(forKey: model.loadItems) {
      await waitUntilCancelled()
    }
    let other = model.tasks.addIsolatedTask(forKey: model.loadItem) {
      await release.wait()
    }
    let second = model.tasks.addIsolatedTask(forKey: model.loadItems) {
      await release.wait()
    }

    #expect(first.isCancelled)
    #expect(!other.isCancelled)
    #expect(!second.isCancelled)
    #expect(model.tasks.runningTaskCount == 2)
    #expect(model.tasks.currentTask(forKey: model.loadItems) == second)
    #expect(model.tasks.currentTask(forKey: model.loadItem) == other)

    await release.open()
    await first.value
    await other.value
    await second.value
  }

  @Test
  func `a keyless store tracks tasks by TaskKey`() async {
    let model = Model()
    let release = Gate()

    let name = TestState<String?>(nil)

    let task = model.tasks.addIsolatedTask(forKey: model.loadItem(1)) {
      if #available(macOS 26.0, iOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *) {
        await name.set(Task.name)
      }
      await release.wait()
    }
    #expect(model.tasks.taskIsRunning(forKey: model.loadItem(1)))
    #expect(!model.tasks.taskIsRunning(forKey: model.loadItem(2)))

    await release.open()
    await task.value
    #expect(!model.tasks.taskIsRunning(forKey: model.loadItem(1)))
    if #available(macOS 26.0, iOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *) {
      #expect(await name.value == "Model.loadItem(1)")
    }
  }
}
