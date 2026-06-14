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
        XCTAssertEqual(config.logViewerActivationGesture, .longPress)
        XCTAssertTrue(config.trackScreenLoadingTimes)
    }

    func testStagingDefaults() {
        let config = LogEnvironment.staging.defaultConfiguration
        XCTAssertEqual(config.minimumLogLevel, .info)
        XCTAssertFalse(config.shouldLogToConsole)
        XCTAssertTrue(config.shouldLogToFile)
        XCTAssertTrue(config.enableInAppLogViewer)
    }

    func testProductionDefaults() {
        let config = LogEnvironment.production.defaultConfiguration
        XCTAssertEqual(config.minimumLogLevel, .warning)
        XCTAssertFalse(config.shouldLogToConsole)
        XCTAssertTrue(config.shouldLogToFile)
        XCTAssertTrue(config.shouldDetectCrashes)
        XCTAssertFalse(config.enableInAppLogViewer)
    }

    func testRawValues() {
        XCTAssertEqual(LogEnvironment.development.rawValue, "development")
        XCTAssertEqual(LogEnvironment.staging.rawValue, "staging")
        XCTAssertEqual(LogEnvironment.production.rawValue, "production")
    }

    func testInitFromRawValue() {
        XCTAssertEqual(LogEnvironment(rawValue: "development"), .development)
        XCTAssertEqual(LogEnvironment(rawValue: "staging"), .staging)
        XCTAssertEqual(LogEnvironment(rawValue: "production"), .production)
        XCTAssertNil(LogEnvironment(rawValue: "unknown"))
        XCTAssertNil(LogEnvironment(rawValue: ""))
    }
}
