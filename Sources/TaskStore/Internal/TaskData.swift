@usableFromInline
struct TaskData: Sendable, Equatable {
  @usableFromInline
  var id: UInt64

  @usableFromInline
  var task: Task<Void, Never>
  
  @inlinable
  init(id: UInt64, task: Task<Void, Never>) {
    self.id = id
    self.task = task
  }
}
