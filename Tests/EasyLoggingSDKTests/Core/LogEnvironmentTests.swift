import XCTest
@testable import EasyLoggingSDK

final class LogEnvironmentTests: XCTestCase {

    func testDevelopmentDefaults() {
        let config = LogEnvironment.development.defaultConfiguration
        XCTAssertEqual(config.minimumLogLevel, .debug)
        XCTAssertTrue(config.shouldLogToConsole)
        XCTAssertTrue(config.shouldLogToFile)
        XCTAssertTrue(config.enableShakeToShare)
        XCTAssertTrue(config.enableInAppLogViewer)
        XCTAssertTrue(config.enableMemoryLeakDetection)
        XCTAssertTrue(config.trackScreenLoadingTimes)
    }

    func testStagingDefaults() {
        let config = LogEnvironment.staging.defaultConfiguration
        XCTAssertEqual(config.minimumLogLevel, .info)
        XCTAssertFalse(config.shouldLogToConsole)
        XCTAssertTrue(config.shouldLogToFile)
        XCTAssertTrue(config.enableInAppLogViewer)
        XCTAssertEqual(config.logViewerAccessCode, "qa_access")
    }

    func testProductionDefaults() {
        let config = LogEnvironment.production.defaultConfiguration
        XCTAssertEqual(config.minimumLogLevel, .warning)
        XCTAssertFalse(config.shouldLogToConsole)
        XCTAssertTrue(config.shouldLogToFile)
        XCTAssertTrue(config.shouldDetectCrashes)
        XCTAssertFalse(config.enableInAppLogViewer)
    }

    func testCustomDefaults() {
        let config = LogEnvironment.custom.defaultConfiguration
        XCTAssertEqual(config.minimumLogLevel, .info)
        XCTAssertTrue(config.shouldLogToFile)
    }

    func testRawValues() {
        XCTAssertEqual(LogEnvironment.development.rawValue, "development")
        XCTAssertEqual(LogEnvironment.staging.rawValue, "staging")
        XCTAssertEqual(LogEnvironment.production.rawValue, "production")
        XCTAssertEqual(LogEnvironment.custom.rawValue, "custom")
    }

    func testInitFromRawValue() {
        XCTAssertEqual(LogEnvironment(rawValue: "development"), .development)
        XCTAssertEqual(LogEnvironment(rawValue: "staging"), .staging)
        XCTAssertEqual(LogEnvironment(rawValue: "production"), .production)
        XCTAssertEqual(LogEnvironment(rawValue: "custom"), .custom)
        XCTAssertNil(LogEnvironment(rawValue: "unknown"))
        XCTAssertNil(LogEnvironment(rawValue: ""))
    }
}
