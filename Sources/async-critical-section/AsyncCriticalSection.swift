/// namespace class
@available(macOS 10.15, *)
public final class Async { }

// MARK: constructor
@available(macOS 10.15, *)
public extension Async {
 
    actor CriticalSection {
        
        private let safe: SafeState
        
        public init() { self.safe = SafeState() }
        
    }
    
}

// MARK: interface
@available(macOS 10.15, *)
public extension Async.CriticalSection {
    
    func isolated(_ isolation: @Sendable @escaping () async throws -> Void,
                  catch: @escaping (Error) -> Void = { print("[x][CriticalSection] isolated() error: \($0)") })
    async {
        let targetId: Int = await self.safe.enqueue(isolation)
        while let next: Running = await safe.runNext() {
            let completedId: Int = await next.execute(else: `catch`)
            if completedId == targetId { return }
        }
    }
    
}

// MARK: safe state
@available(macOS 10.15, *)
private extension Async.CriticalSection {
    
    private final actor SafeState {
        
        private var queue: [Scheduled]
        private var previousId: Int
        private var inProgress: Running?
        
        init() {
            self.queue = [ ]
            self.previousId = -1
            self.inProgress = nil
        }
        
        func enqueue(_ isolation: @Sendable @escaping () async throws -> Void) -> Int {
            let id: Int = nextId()
            self.queue.append((id, isolation))
            return id
        }
        
        func runNext() -> Running? {
            if let inProgress: Running { return inProgress }
            guard let next: Scheduled = self.next else { return nil }
            self.inProgress = Running(next.id, Execution { try await next.isolation(); self.inProgress = nil })
            return inProgress
        }
        
        private var next: Scheduled? { queue.isEmpty ? nil : queue.removeFirst() }
        
        private func nextId() -> Int {
            let id: Int = (previousId == Int.max) ? 0 : previousId + 1
            self.previousId = id
            return id
        }
        
        typealias Scheduled = (id: Int, isolation: () async throws -> Void)
        
    }
    
}

@available(macOS 10.15, *)
private extension Async.CriticalSection {
    
    final class Running {
        
        let id: Int
        let isolation: Execution
        
        init(_ id: Int, _ isolation: Execution) {
            self.id = id
            self.isolation = isolation
        }
        
        func execute(else catch: @escaping (Error) -> Void) async -> Int {
            do { try await isolation.value } catch { `catch`(error) }
            return id
        }
        
    }
    
    typealias Execution = Async.Task<Void, Error>
    
}

@available(macOS 10.15, *)
public extension Async { typealias Task = _Concurrency.Task }
