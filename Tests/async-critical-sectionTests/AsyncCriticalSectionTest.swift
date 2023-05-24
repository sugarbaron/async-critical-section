import XCTest
@testable import async_critical_section

extension Async.CriticalSection {
    
    final class Test : XCTestCase {
        
        private let section: Async.CriticalSection = .init()
        private let inspector: Inspector = .init()
        
        func testCriticalSection() throws {
            let testComplete: DispatchSemaphore = .init(value: 0)
            asyncTest(with: testComplete)
            testComplete.wait()
        }
        
        private func asyncTest(with testComplete: DispatchSemaphore) { Async.Task {
            async let execution1: Void = asyncSafeAccess(1)
            async let execution2: Void = asyncSafeAccess(2)
            async let execution3: Void = asyncSafeAccess(3)
            async let execution4: Void = asyncSafeAccess(4)
            async let execution5: Void = asyncSafeAccess(5)
            
            let _: [Void] = await [execution1,
                                   execution2,
                                   execution3,
                                   execution4,
                                   execution5]
            testComplete.signal()
        } }
        
        private func asyncSafeAccess(_ clientId: Int) async {
            // Log("[IsolationTest] [\(clientId)]:await")
            await section.isolated { [weak self] in
                // Log("[IsolationTest] [\(clientId)]:1")
                self?.inspector.register(start: clientId)
                let iterations: Int = Int(1e5)
                for i in 0..<iterations { let _: Int = i + 1 }
                // Log("[IsolationTest] [\(clientId)]:2")
                for i in 0..<iterations { let _: Int = i + 1 }
                // Log("[IsolationTest] [\(clientId)]:3")
                for i in 0..<iterations { let _: Int = i + 1 }
                // Log("[IsolationTest] [\(clientId)]:4")
                let duration: UInt64 = .init(0.1 * 1e9)
                try await Task.sleep(nanoseconds: duration)
                // Log("[IsolationTest] [\(clientId)]:5")
                try await Task.sleep(nanoseconds: duration)
                // Log("[IsolationTest] [\(clientId)]:6")
                try await Task.sleep(nanoseconds: duration)
                self?.inspector.register(termination: clientId)
                // Log("[IsolationTest] [\(clientId)]:7")
            }
        }
        
        private final class Inspector {
            
            private var running: Int?
            
            init() { self.running = nil }
            
            func register(start clientId: Int) {
                let warning: String = "[CriticalSection] too early:[\(clientId)] while:[\(dbgRunning)] is in progress"
                XCTAssertNil(running, warning)
                running = clientId
            }
            
            func register(termination clientId: Int) {
                let warning: String = "[CriticalSection] [\(dbgRunning)] is in progress, but:[\(clientId)] terminates"
                XCTAssertEqual(clientId, running, warning)
                running = nil
            }
            
            private var dbgRunning: String { if let running: Int { return "\(running)" } else { return "<nil>" } }
            
        }
        
    }
    
}
