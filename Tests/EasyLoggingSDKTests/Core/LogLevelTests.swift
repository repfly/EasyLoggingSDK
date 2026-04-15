import XCTest
@testable import EasyLoggingSDK

final class LogLevelTests: XCTestCase {

    // MARK: - Ordering

    func testLogLevelOrderingBySeverity() {
        XCTAssertTrue(LogLevel.debug < LogLevel.info)
        XCTAssertTrue(LogLevel.info < LogLevel.warning)
        XCTAssertTrue(LogLevel.warning < LogLevel.error)
    }

    func testDebugIsLessThanError() {
        XCTAssertTrue(LogLevel.debug < LogLevel.error)
    }

    func testErrorIsNotLessThanDebug() {
        XCTAssertFalse(LogLevel.error < LogLevel.debug)
    }

    func testEqualLevelsAreNotLessThan() {
        XCTAssertFalse(LogLevel.info < LogLevel.info)
    }

    // MARK: - Raw Values

    func testRawValuesAreIntegers() {
        XCTAssertEqual(LogLevel.debug.rawValue, 0)
        XCTAssertEqual(LogLevel.info.rawValue, 1)
        XCTAssertEqual(LogLevel.warning.rawValue, 2)
        XCTAssertEqual(LogLevel.error.rawValue, 3)
    }

    // MARK: - String Values

    func testStringValues() {
        XCTAssertEqual(LogLevel.debug.stringValue, "debug")
        XCTAssertEqual(LogLevel.info.stringValue, "info")
        XCTAssertEqual(LogLevel.warning.stringValue, "warning")
        XCTAssertEqual(LogLevel.error.stringValue, "error")
    }

    // MARK: - fromString

    func testFromStringValid() {
        XCTAssertEqual(LogLevel.fromString("debug"), .debug)
        XCTAssertEqual(LogLevel.fromString("info"), .info)
        XCTAssertEqual(LogLevel.fromString("warning"), .warning)
        XCTAssertEqual(LogLevel.fromString("error"), .error)
    }

    func testFromStringCaseInsensitive() {
        XCTAssertEqual(LogLevel.fromString("DEBUG"), .debug)
        XCTAssertEqual(LogLevel.fromString("Info"), .info)
        XCTAssertEqual(LogLevel.fromString("WARNING"), .warning)
    }

    func testFromStringInvalid() {
        XCTAssertNil(LogLevel.fromString("verbose"))
        XCTAssertNil(LogLevel.fromString(""))
        XCTAssertNil(LogLevel.fromString("critical"))
    }

    // MARK: - Log Description Prefix

    func testLogDescriptionPrefixes() {
        XCTAssertTrue(LogLevel.debug.logDescriptionPrefix.contains("DEBUG"))
        XCTAssertTrue(LogLevel.info.logDescriptionPrefix.contains("INFO"))
        XCTAssertTrue(LogLevel.warning.logDescriptionPrefix.contains("WARNING"))
        XCTAssertTrue(LogLevel.error.logDescriptionPrefix.contains("ERROR"))
    }

    // MARK: - Filtering Logic

    func testFilteringWithMinimumLevel() {
        let minimumLevel = LogLevel.warning

        // These should pass the filter (level >= minimum)
        XCTAssertTrue(LogLevel.warning.rawValue >= minimumLevel.rawValue)
        XCTAssertTrue(LogLevel.error.rawValue >= minimumLevel.rawValue)

        // These should be filtered out
        XCTAssertFalse(LogLevel.debug.rawValue >= minimumLevel.rawValue)
        XCTAssertFalse(LogLevel.info.rawValue >= minimumLevel.rawValue)
    }

    func testFilteringWithErrorMinimum() {
        let minimumLevel = LogLevel.error

        XCTAssertTrue(LogLevel.error.rawValue >= minimumLevel.rawValue)
        XCTAssertFalse(LogLevel.debug.rawValue >= minimumLevel.rawValue)
        XCTAssertFalse(LogLevel.info.rawValue >= minimumLevel.rawValue)
        XCTAssertFalse(LogLevel.warning.rawValue >= minimumLevel.rawValue)
    }

    func testFilteringWithDebugMinimum() {
        let minimumLevel = LogLevel.debug

        // All levels should pass when minimum is debug
        XCTAssertTrue(LogLevel.debug.rawValue >= minimumLevel.rawValue)
        XCTAssertTrue(LogLevel.info.rawValue >= minimumLevel.rawValue)
        XCTAssertTrue(LogLevel.warning.rawValue >= minimumLevel.rawValue)
        XCTAssertTrue(LogLevel.error.rawValue >= minimumLevel.rawValue)
    }
}
