import XCTest
@testable import EasyLoggingSDK

final class ThreadSafetyTests: XCTestCase {

    // MARK: - Configuration Thread Safety

    func testConcurrentConfigurationReadWrite() {
        let expectation = XCTestExpectation(description: "Concurrent config access")
        let iterations = 1000
        let group = DispatchGroup()

        // Concurrent writers
        for index in 0..<iterations {
            group.enter()
            DispatchQueue.global().async {
                var config = EasyLogger.Configuration()
                config.minimumLogLevel = index % 2 == 0 ? .debug : .error
                config.maxFileSize = UInt64(index)
                EasyLogger.shared.configure(config)
                group.leave()
            }
        }

        // Concurrent readers
        for _ in 0..<iterations {
            group.enter()
            DispatchQueue.global().async {
                let config = EasyLogger.shared.configuration
                // Just verify we can read without crashing
                _ = config.minimumLogLevel
                _ = config.maxFileSize
                group.leave()
            }
        }

        group.notify(queue: .main) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    // MARK: - Environment Thread Safety

    func testConcurrentEnvironmentReadWrite() {
        let expectation = XCTestExpectation(description: "Concurrent env access")
        let iterations = 1000
        let group = DispatchGroup()

        let environments: [LogEnvironment] = [.development, .staging, .production]

        for index in 0..<iterations {
            group.enter()
            DispatchQueue.global().async {
                EasyLogger.shared.setEnvironment(environments[index % environments.count])
                group.leave()
            }
        }

        for _ in 0..<iterations {
            group.enter()
            DispatchQueue.global().async {
                _ = EasyLogger.shared.environment
                group.leave()
            }
        }

        group.notify(queue: .main) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    // MARK: - isEnabled Thread Safety

    func testConcurrentIsEnabled() {
        let expectation = XCTestExpectation(description: "Concurrent isEnabled")
        let iterations = 1000
        let group = DispatchGroup()

        let levels: [LogLevel] = [.trace, .debug, .info, .warning, .error, .critical]

        for index in 0..<iterations {
            group.enter()
            DispatchQueue.global().async {
                _ = EasyLogger.shared.isEnabled(level: levels[index % levels.count])
                group.leave()
            }
        }

        group.notify(queue: .main) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    // MARK: - UnfairLock

    func testUnfairLockWithLock() {
        // Heap-allocated counter so the concurrent closures mutate a shared reference's property
        // (guarded by the lock under test) rather than a captured `var` — the latter is a Swift 6
        // data-race error. The lock is exactly what makes this safe, which is what we're verifying.
        final class Counter: @unchecked Sendable { var value = 0 }
        let counter = Counter()
        let lock = UnfairLock()
        let iterations = 10_000
        let expectation = XCTestExpectation(description: "Lock contention")
        let group = DispatchGroup()

        for _ in 0..<iterations {
            group.enter()
            DispatchQueue.global().async {
                lock.withLock {
                    counter.value += 1
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            XCTAssertEqual(counter.value, iterations)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    func testUnfairLockWithLockReturnsValue() {
        let lock = UnfairLock()
        let result = lock.withLock { 42 }
        XCTAssertEqual(result, 42)
    }
}
