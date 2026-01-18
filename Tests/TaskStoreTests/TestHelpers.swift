//===----------------------------------------------------------------------===//
//
// This source file is part of the swift-task-store open source project
//
// Copyright (c) June Bash
//
// See LICENSE for license information
//
//===----------------------------------------------------------------------===//

import Foundation
import Observation

/// Thread-safe container for tracking values in tests.
actor TestState<T: Sendable> {
  private var _value: T

  init(_ initial: T) {
    self._value = initial
  }

  var value: T { _value }

  func set(_ newValue: T) {
    _value = newValue
  }
}

/// Thread-safe container for tracking ordered events in tests.
actor OrderTracker {
  private var events: [String] = []

  func append(_ event: String) {
    events.append(event)
  }

  var allEvents: [String] { events }
}

@available(macOS 15.0, *)
struct RemoveDuplicates<Base: AsyncSequence>: AsyncSequence {
  let base: Base
  let areDuplicates: (Base.Element, Base.Element) -> Bool

  struct Iterator: AsyncIteratorProtocol {
    var base: Base.AsyncIterator?
    var lastValue: Base.Element? = nil
    let areDuplicates: (Base.Element, Base.Element) -> Bool

    mutating func next(
      isolation: isolated (any Actor)?
    ) async throws(Base.Failure) -> Base.Element? {
      do {
        while let next = try await base?.next(isolation: isolation) {
          let lastValue = self.lastValue
          self.lastValue = next
          if let lastValue, areDuplicates(lastValue, next) {
            continue
          } else {
            return next
          }
        }
        return nil
      } catch {
        self.base = nil
        throw error
      }
    }
  }

  func makeAsyncIterator() -> Iterator {
    Iterator(base: base.makeAsyncIterator(), lastValue: nil, areDuplicates: areDuplicates)
  }
}

extension AsyncSequence {
  @available(macOS 15.0, *)
  func removeDuplicates(
    _ areDuplicates: @escaping (Element, Element) -> Bool
  ) -> RemoveDuplicates<Self> {
    RemoveDuplicates(base: self, areDuplicates: areDuplicates)
  }

  @available(macOS 15.0, *)
  func removeDuplicates() -> RemoveDuplicates<Self> where Element: Equatable {
    removeDuplicates(==)
  }
}

@globalActor
actor TestIsolation {
  static let shared = TestIsolation()
}
