import Foundation

@usableFromInline
struct TaskData: Sendable, Equatable {
  @usableFromInline
  var id: UUID
  
  @usableFromInline
  var task: Task<Void, Never>
  
  @inlinable
  init(id: UUID, task: Task<Void, Never>) {
    self.id = id
    self.task = task
  }
}
