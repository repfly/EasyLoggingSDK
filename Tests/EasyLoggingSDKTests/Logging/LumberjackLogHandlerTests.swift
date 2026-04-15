import XCTest
import Logging
@testable import EasyLoggingSDK

final class LumberjackLogHandlerTests: XCTestCase {

    func testInitializationDefaults() {
        var handler = LumberjackLogHandler(label: "test")
        XCTAssertEqual(handler.logLevel, .debug)
        XCTAssertTrue(handler.metadata.isEmpty)
    }

    func testInitializationWithMinimumLevel() {
        var handler = LumberjackLogHandler(label: "test", minimumLogLevel: .warning)
        XCTAssertEqual(handler.logLevel, .warning)
    }

    func testLogLevelGetSet() {
        var handler = LumberjackLogHandler(label: "test")
        handler.logLevel = .error
        XCTAssertEqual(handler.logLevel, .error)
    }

    func testMetadataGetSet() {
        var handler = LumberjackLogHandler(label: "test")
        handler.metadata["key"] = "value"
        XCTAssertEqual(handler.metadata["key"], "value")
    }

    func testMetadataSubscript() {
        var handler = LumberjackLogHandler(label: "test")
        handler[metadataKey: "testKey"] = "testValue"
        XCTAssertEqual(handler[metadataKey: "testKey"], "testValue")
    }

    func testMetadataSubscriptRemoval() {
        var handler = LumberjackLogHandler(label: "test")
        handler[metadataKey: "key"] = "value"
        handler[metadataKey: "key"] = nil
        XCTAssertNil(handler[metadataKey: "key"])
    }
}
