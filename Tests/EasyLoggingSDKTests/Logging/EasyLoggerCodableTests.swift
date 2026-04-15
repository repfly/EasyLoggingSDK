import XCTest
import CocoaLumberjack
@testable import EasyLoggingSDK

final class EasyLoggerCodableTests: XCTestCase {

    override func setUp() {
        super.setUp()
        DDLog.removeAllLoggers()
    }

    override func tearDown() {
        DDLog.removeAllLoggers()
        super.tearDown()
    }

    // MARK: - Codable Metadata Encoding

    private struct UserInfo: Codable {
        let name: String
        let age: Int
    }

    func testCodableMetadataEncoding() {
        let logger = EasyLogger.shared
        let user = UserInfo(name: "Test", age: 25)

        // Should not crash
        logger.info("User logged in", metadata: user)
    }

    func testDictionaryMetadata() {
        let logger = EasyLogger.shared
        let metadata: [String: Any] = ["key": "value", "count": 42]

        // Should not crash
        logger.info("Event occurred", metadata: metadata)
    }

    func testNilMetadata() {
        let logger = EasyLogger.shared

        // Should not crash
        logger.info("Simple message", metadata: nil)
    }

    func testConvenienceMethodsWithMetadata() {
        let logger = EasyLogger.shared
        let user = UserInfo(name: "Test", age: 30)

        // All convenience methods should work without crashing
        logger.debug("Debug", metadata: user)
        logger.info("Info", metadata: user)
        logger.warning("Warning", metadata: user)
        logger.error("Error", metadata: user)
    }

    func testConvenienceMethodsWithDictionary() {
        let logger = EasyLogger.shared
        let meta: [String: Any] = ["source": "test"]

        logger.debug("Debug", metadata: meta)
        logger.info("Info", metadata: meta)
        logger.warning("Warning", metadata: meta)
        logger.error("Error", metadata: meta)
    }
}
