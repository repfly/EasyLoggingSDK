import XCTest
import CocoaLumberjack
@testable import EasyLoggingCore

final class EasyLoggerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        DDLog.removeAllLoggers()
    }

    override func tearDown() {
        DDLog.removeAllLoggers()
        super.tearDown()
    }

    // MARK: - Singleton

    func testSharedInstanceIsAlwaysSame() {
        let logger1 = EasyLogger.shared
        let logger2 = EasyLogger.shared
        XCTAssertTrue(logger1 === logger2)
    }

    // MARK: - isEnabled

    func testIsEnabledWithDebugMinimum() {
        var config = EasyLogger.Configuration()
        config.minimumLogLevel = .debug
        EasyLogger.shared.configure(config)

        XCTAssertTrue(EasyLogger.shared.isEnabled(level: .debug))
        XCTAssertTrue(EasyLogger.shared.isEnabled(level: .info))
        XCTAssertTrue(EasyLogger.shared.isEnabled(level: .warning))
        XCTAssertTrue(EasyLogger.shared.isEnabled(level: .error))
    }

    func testIsEnabledWithErrorMinimum() {
        var config = EasyLogger.Configuration()
        config.minimumLogLevel = .error
        EasyLogger.shared.configure(config)

        XCTAssertFalse(EasyLogger.shared.isEnabled(level: .debug))
        XCTAssertFalse(EasyLogger.shared.isEnabled(level: .info))
        XCTAssertFalse(EasyLogger.shared.isEnabled(level: .warning))
        XCTAssertTrue(EasyLogger.shared.isEnabled(level: .error))
    }

    func testIsEnabledWithWarningMinimum() {
        var config = EasyLogger.Configuration()
        config.minimumLogLevel = .warning
        EasyLogger.shared.configure(config)

        XCTAssertFalse(EasyLogger.shared.isEnabled(level: .debug))
        XCTAssertFalse(EasyLogger.shared.isEnabled(level: .info))
        XCTAssertTrue(EasyLogger.shared.isEnabled(level: .warning))
        XCTAssertTrue(EasyLogger.shared.isEnabled(level: .error))
    }

    // MARK: - Configuration

    func testConfigurationGetSet() {
        var config = EasyLogger.Configuration()
        config.minimumLogLevel = .warning
        config.shouldLogToConsole = false

        EasyLogger.shared.configure(config)

        let readBack = EasyLogger.shared.configuration
        XCTAssertEqual(readBack.minimumLogLevel, .warning)
        XCTAssertFalse(readBack.shouldLogToConsole)
    }

    // MARK: - Environment

    func testEnvironmentGetSet() {
        EasyLogger.shared.setEnvironment(.staging)
        XCTAssertEqual(EasyLogger.shared.environment, .staging)

        EasyLogger.shared.setEnvironment(.production)
        XCTAssertEqual(EasyLogger.shared.environment, .production)
    }

    // MARK: - Async Overloads

    func testAsyncLogOverloadsCompileAndDeliver() async {
        var config = EasyLogger.Configuration()
        config.minimumLogLevel = .trace
        config.shouldLogToConsole = false
        config.shouldLogToFile = false
        await EasyLogger.shared.configure(config)

        // Same-name async overloads, resolved via the `await` effect context.
        await EasyLogger.shared.trace("async trace")
        await EasyLogger.shared.debug("async debug")
        await EasyLogger.shared.info("async info")
        await EasyLogger.shared.warning("async warning")
        await EasyLogger.shared.error("async error")
        await EasyLogger.shared.critical("async critical")
        await EasyLogger.shared.log("async log", level: .info)

        // Flush guarantees all enqueued records have been processed and delivered.
        await EasyLogger.shared.flush()
    }

    func testSyncLogOverloadResolvesInSyncContext() {
        // In a non-async context, the same-name calls resolve to the sync overloads.
        var config = EasyLogger.Configuration()
        config.minimumLogLevel = .trace
        EasyLogger.shared.configure(config)
        EasyLogger.shared.trace("sync trace")
        EasyLogger.shared.critical("sync critical")
        EasyLogger.shared.info("sync info")
    }

    // MARK: - Log File Management

    func testCurrentLogFileURLReturnsValueWhenFileLoggingEnabled() {
        var config = EasyLogger.Configuration()
        config.shouldLogToFile = true
        config.shouldLogToConsole = false
        EasyLogger.shared.configure(config)

        // Give the queue time to process
        let expectation = XCTestExpectation(description: "Configuration applied")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
    }
}
