import XCTest
import CocoaLumberjack
import Logging
@testable import EasyLoggingCore

final class LogLevelTests: XCTestCase {

    // MARK: - Ordering

    func testLogLevelOrderingBySeverity() {
        XCTAssertTrue(LogLevel.trace < LogLevel.debug)
        XCTAssertTrue(LogLevel.debug < LogLevel.info)
        XCTAssertTrue(LogLevel.info < LogLevel.warning)
        XCTAssertTrue(LogLevel.warning < LogLevel.error)
        XCTAssertTrue(LogLevel.error < LogLevel.critical)
    }

    func testTraceIsLessThanDebug() {
        XCTAssertTrue(LogLevel.trace < LogLevel.debug)
    }

    func testErrorIsLessThanCritical() {
        XCTAssertTrue(LogLevel.error < LogLevel.critical)
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
        XCTAssertEqual(LogLevel.trace.rawValue, 0)
        XCTAssertEqual(LogLevel.debug.rawValue, 1)
        XCTAssertEqual(LogLevel.info.rawValue, 2)
        XCTAssertEqual(LogLevel.warning.rawValue, 3)
        XCTAssertEqual(LogLevel.error.rawValue, 4)
        XCTAssertEqual(LogLevel.critical.rawValue, 5)
    }

    // MARK: - Description (CustomStringConvertible)

    func testDescriptionValues() {
        XCTAssertEqual(LogLevel.trace.description, "trace")
        XCTAssertEqual(LogLevel.debug.description, "debug")
        XCTAssertEqual(LogLevel.info.description, "info")
        XCTAssertEqual(LogLevel.warning.description, "warning")
        XCTAssertEqual(LogLevel.error.description, "error")
        XCTAssertEqual(LogLevel.critical.description, "critical")
    }

    func testDescriptionRoundTripsViaInitName() {
        for level in [LogLevel.trace, .debug, .info, .warning, .error, .critical] {
            XCTAssertEqual(LogLevel(name: level.description), level)
        }
    }

    // MARK: - init?(name:)

    func testInitNameValid() {
        XCTAssertEqual(LogLevel(name: "trace"), .trace)
        XCTAssertEqual(LogLevel(name: "debug"), .debug)
        XCTAssertEqual(LogLevel(name: "info"), .info)
        XCTAssertEqual(LogLevel(name: "warning"), .warning)
        XCTAssertEqual(LogLevel(name: "error"), .error)
        XCTAssertEqual(LogLevel(name: "critical"), .critical)
    }

    func testInitNameCaseInsensitive() {
        XCTAssertEqual(LogLevel(name: "TRACE"), .trace)
        XCTAssertEqual(LogLevel(name: "DEBUG"), .debug)
        XCTAssertEqual(LogLevel(name: "Info"), .info)
        XCTAssertEqual(LogLevel(name: "WARNING"), .warning)
        XCTAssertEqual(LogLevel(name: "Critical"), .critical)
    }

    func testInitNameInvalid() {
        XCTAssertNil(LogLevel(name: "verbose"))
        XCTAssertNil(LogLevel(name: ""))
        XCTAssertNil(LogLevel(name: "fatal"))
    }

    // MARK: - DDLogLevel / DDLogFlag Mapping

    func testDDLogLevelMapping() {
        XCTAssertEqual(LogLevel.trace.ddLogLevel, .verbose)
        XCTAssertEqual(LogLevel.debug.ddLogLevel, .debug)
        XCTAssertEqual(LogLevel.info.ddLogLevel, .info)
        XCTAssertEqual(LogLevel.warning.ddLogLevel, .warning)
        XCTAssertEqual(LogLevel.error.ddLogLevel, .error)
        XCTAssertEqual(LogLevel.critical.ddLogLevel, .error)
    }

    func testDDLogFlagMapping() {
        XCTAssertEqual(LogLevel.trace.flag, .verbose)
        XCTAssertEqual(LogLevel.debug.flag, .debug)
        XCTAssertEqual(LogLevel.info.flag, .info)
        XCTAssertEqual(LogLevel.warning.flag, .warning)
        XCTAssertEqual(LogLevel.error.flag, .error)
        XCTAssertEqual(LogLevel.critical.flag, .error)
    }

    func testInitFromDDLogLevel() {
        XCTAssertEqual(LogLevel(from: .verbose), .trace)
        XCTAssertEqual(LogLevel(from: .debug), .debug)
        XCTAssertEqual(LogLevel(from: .info), .info)
        XCTAssertEqual(LogLevel(from: .warning), .warning)
        XCTAssertEqual(LogLevel(from: .error), .error)
    }

    // MARK: - swift-log Mapping

    func testToSwiftLogLevel() {
        XCTAssertEqual(LogLevel.trace.toSwiftLogLevel(), .trace)
        XCTAssertEqual(LogLevel.debug.toSwiftLogLevel(), .debug)
        XCTAssertEqual(LogLevel.info.toSwiftLogLevel(), .info)
        XCTAssertEqual(LogLevel.warning.toSwiftLogLevel(), .warning)
        XCTAssertEqual(LogLevel.error.toSwiftLogLevel(), .error)
        XCTAssertEqual(LogLevel.critical.toSwiftLogLevel(), .critical)
    }

    func testInitFromSwiftLogLevel() {
        XCTAssertEqual(LogLevel(fromSwiftLogLevel: .trace), .trace)
        XCTAssertEqual(LogLevel(fromSwiftLogLevel: .debug), .debug)
        XCTAssertEqual(LogLevel(fromSwiftLogLevel: .info), .info)
        XCTAssertEqual(LogLevel(fromSwiftLogLevel: .notice), .info)
        XCTAssertEqual(LogLevel(fromSwiftLogLevel: .warning), .warning)
        XCTAssertEqual(LogLevel(fromSwiftLogLevel: .error), .error)
        XCTAssertEqual(LogLevel(fromSwiftLogLevel: .critical), .critical)
    }

    // MARK: - Filtering Logic

    func testFilteringWithMinimumLevel() {
        let minimumLevel = LogLevel.warning

        XCTAssertTrue(LogLevel.warning.rawValue >= minimumLevel.rawValue)
        XCTAssertTrue(LogLevel.error.rawValue >= minimumLevel.rawValue)

        XCTAssertFalse(LogLevel.debug.rawValue >= minimumLevel.rawValue)
        XCTAssertFalse(LogLevel.info.rawValue >= minimumLevel.rawValue)
    }

    func testFilteringWithErrorMinimum() {
        let minimumLevel = LogLevel.error

        XCTAssertTrue(LogLevel.error.rawValue >= minimumLevel.rawValue)
        XCTAssertTrue(LogLevel.critical.rawValue >= minimumLevel.rawValue)
        XCTAssertFalse(LogLevel.debug.rawValue >= minimumLevel.rawValue)
        XCTAssertFalse(LogLevel.info.rawValue >= minimumLevel.rawValue)
        XCTAssertFalse(LogLevel.warning.rawValue >= minimumLevel.rawValue)
    }

    func testFilteringWithTraceMinimum() {
        let minimumLevel = LogLevel.trace

        // All levels should pass when minimum is trace
        for level in [LogLevel.trace, .debug, .info, .warning, .error, .critical] {
            XCTAssertTrue(level.rawValue >= minimumLevel.rawValue)
        }
    }
}
