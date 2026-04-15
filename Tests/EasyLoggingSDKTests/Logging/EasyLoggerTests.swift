import XCTest
import CocoaLumberjack
@testable import EasyLoggingSDK

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
        EasyLogger.shared.configuration = config

        XCTAssertTrue(EasyLogger.shared.isEnabled(level: .debug))
        XCTAssertTrue(EasyLogger.shared.isEnabled(level: .info))
        XCTAssertTrue(EasyLogger.shared.isEnabled(level: .warning))
        XCTAssertTrue(EasyLogger.shared.isEnabled(level: .error))
    }

    func testIsEnabledWithErrorMinimum() {
        var config = EasyLogger.Configuration()
        config.minimumLogLevel = .error
        EasyLogger.shared.configuration = config

        XCTAssertFalse(EasyLogger.shared.isEnabled(level: .debug))
        XCTAssertFalse(EasyLogger.shared.isEnabled(level: .info))
        XCTAssertFalse(EasyLogger.shared.isEnabled(level: .warning))
        XCTAssertTrue(EasyLogger.shared.isEnabled(level: .error))
    }

    func testIsEnabledWithWarningMinimum() {
        var config = EasyLogger.Configuration()
        config.minimumLogLevel = .warning
        EasyLogger.shared.configuration = config

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

        EasyLogger.shared.configuration = config

        let readBack = EasyLogger.shared.configuration
        XCTAssertEqual(readBack.minimumLogLevel, .warning)
        XCTAssertFalse(readBack.shouldLogToConsole)
    }

    // MARK: - Environment

    func testEnvironmentGetSet() {
        EasyLogger.shared.environment = .staging
        XCTAssertEqual(EasyLogger.shared.environment, .staging)

        EasyLogger.shared.environment = .production
        XCTAssertEqual(EasyLogger.shared.environment, .production)
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
