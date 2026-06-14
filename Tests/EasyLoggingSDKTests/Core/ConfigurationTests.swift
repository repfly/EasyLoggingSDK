import XCTest
@testable import EasyLoggingSDK

final class ConfigurationTests: XCTestCase {

    func testDefaultValues() {
        let config = EasyLogger.Configuration()

        XCTAssertEqual(config.minimumLogLevel, .debug)
        XCTAssertTrue(config.shouldLogToConsole)
        XCTAssertTrue(config.shouldLogToFile)
        XCTAssertTrue(config.shouldDetectCrashes)
        XCTAssertFalse(config.enableShakeToShare)
        XCTAssertFalse(config.trackScreenLoadingTimes)
        XCTAssertEqual(config.slowScreenLoadingThreshold, 1.0)
        XCTAssertEqual(config.maxFileSize, 5_000_000)
        XCTAssertEqual(config.maxLogFiles, 7)
        XCTAssertNil(config.logsDirectory)
        XCTAssertFalse(config.useAutomaticUIKitScreenTimeTracking)
        XCTAssertFalse(config.enableInAppLogViewer)
        XCTAssertEqual(config.maxLogViewerEntries, 1000)
    }

    func testCustomConfiguration() {
        var config = EasyLogger.Configuration()
        config.minimumLogLevel = .error
        config.shouldLogToConsole = false
        config.maxFileSize = 10_000_000
        config.logsDirectory = "/custom/logs"

        XCTAssertEqual(config.minimumLogLevel, .error)
        XCTAssertFalse(config.shouldLogToConsole)
        XCTAssertEqual(config.maxFileSize, 10_000_000)
        XCTAssertEqual(config.logsDirectory, "/custom/logs")
    }

    func testConfigurationIsSendable() {
        let config = EasyLogger.Configuration()

        // Verify Configuration can be sent across actor boundaries
        Task {
            let _ = config.minimumLogLevel
        }
    }
}
