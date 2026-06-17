import XCTest
@testable import EasyLoggingCore

/// End-to-end integration coverage for the consolidated public surface.
///
/// Drives ``EasyLogger/shared`` the way a consumer would: apply a custom
/// ``EasyLogger/Configuration``, log at every level both synchronously and via the `async`
/// overloads, and `flush()` to guarantee delivery. These tests are macOS-runnable and use no
/// UIKit APIs.
///
/// - Note: `EasyLogger` exposes both a synchronous and an `async` overload for `configure`/`log`.
///   In an `async` context Swift selects the `async` overload, so the synchronous surface is
///   exercised from a non-`async` test method, while the async surface lives in `async` tests.
final class PublicSurfaceIntegrationTests: XCTestCase {

    private func makeIntegrationConfiguration() -> EasyLogger.Configuration {
        var config = EasyLogger.Configuration()
        // Exercise the lowest level so every severity is recorded, but keep file logging on to
        // drive the full on-disk path. UIKit-only features stay off (macOS-runnable).
        config.minimumLogLevel = .trace
        config.shouldLogToConsole = false
        config.shouldLogToFile = true
        config.logFormat = .detailed
        config.enableShakeToShare = false
        config.enableInAppLogViewer = false
        config.enableNetworkLogging = false
        return config
    }

    /// Synchronous surface: configure + log every level from a non-async context (so the sync
    /// overloads are selected), then flush via an expectation.
    func testConfigureThenLogEveryLevelSyncThenFlush() {
        let logger = EasyLogger.shared
        logger.configure(makeIntegrationConfiguration())

        let metadata: LogMetadata = ["scenario": "integration", "attempt": 1]

        logger.trace("trace line", category: "integration", metadata: metadata)
        logger.debug("debug line", category: "integration", metadata: metadata)
        logger.info("info line", category: "integration", metadata: metadata)
        logger.warning("warning line", category: "integration", metadata: metadata)
        logger.error("error line", category: "integration", metadata: metadata)
        logger.critical("critical line", category: "integration", metadata: metadata)

        // Flush must return — proving all enqueued records drained without crashing.
        let expectation = XCTestExpectation(description: "sync flush returns")
        Task {
            await logger.flush()
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 5.0)
    }

    /// Async surface: every level through the `async` overloads, then a final flush.
    func testAsyncOverloadsAtEveryLevel() async {
        let logger = EasyLogger.shared
        await logger.configure(makeIntegrationConfiguration())

        await logger.trace("async trace")
        await logger.debug("async debug")
        await logger.info("async info", metadata: ["k": "v"])
        await logger.warning("async warning")
        await logger.error("async error")
        await logger.critical("async critical")

        // Each async overload already awaits its own flush; a final flush still must return.
        await logger.flush()
    }

    func testFlushReturnsAfterAsyncLogging() async {
        let logger = EasyLogger.shared
        await logger.configure(makeIntegrationConfiguration())

        for index in 0..<50 {
            await logger.info("async \(index)", category: "mixed")
        }

        let expectation = XCTestExpectation(description: "flush returns")
        Task {
            await logger.flush()
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 5.0)
    }

    func testIsEnabledReflectsConfiguredMinimumLevel() {
        let logger = EasyLogger.shared
        var config = makeIntegrationConfiguration()
        config.minimumLogLevel = .warning
        logger.configure(config)

        XCTAssertFalse(logger.isEnabled(level: .debug))
        XCTAssertTrue(logger.isEnabled(level: .warning))
        XCTAssertTrue(logger.isEnabled(level: .critical))
    }
}
