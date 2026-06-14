import XCTest
@testable import EasyLoggingSDK

final class ThreadSafetyTests: XCTestCase {

    // MARK: - Configuration Thread Safety

    func testConcurrentConfigurationReadWrite() {
        let expectation = XCTestExpectation(description: "Concurrent config access")
        let iterations = 1000
        let group = DispatchGroup()

        // Concurrent writers
        for i in 0..<iterations {
            group.enter()
            DispatchQueue.global().async {
                var config = EasyLogger.Configuration()
                config.minimumLogLevel = i % 2 == 0 ? .debug : .error
                config.maxFileSize = UInt64(i)
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
                let _ = config.minimumLogLevel
                let _ = config.maxFileSize
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

        for i in 0..<iterations {
            group.enter()
            DispatchQueue.global().async {
                EasyLogger.shared.setEnvironment(environments[i % environments.count])
                group.leave()
            }
        }

        for _ in 0..<iterations {
            group.enter()
            DispatchQueue.global().async {
                let _ = EasyLogger.shared.environment
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

        for i in 0..<iterations {
            group.enter()
            DispatchQueue.global().async {
                let _ = EasyLogger.shared.isEnabled(level: levels[i % levels.count])
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
        let lock = UnfairLock()
        var counter = 0
        let iterations = 10_000
        let expectation = XCTestExpectation(description: "Lock contention")
        let group = DispatchGroup()

        for _ in 0..<iterations {
            group.enter()
            DispatchQueue.global().async {
                lock.withLock {
                    counter += 1
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            XCTAssertEqual(counter, iterations)
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
