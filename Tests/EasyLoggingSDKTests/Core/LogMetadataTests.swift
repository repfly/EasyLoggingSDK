import XCTest
@testable import EasyLoggingCore

final class LogMetadataTests: XCTestCase {

    func testEmptyInit() {
        let metadata = LogMetadata()
        XCTAssertTrue(metadata.isEmpty)
        XCTAssertTrue(metadata.stringDictionary.isEmpty)
    }

    func testDictionaryLiteralInit() {
        let metadata: LogMetadata = [
            "userId": "abc123",
            "retryCount": 3,
            "latency": 0.245
        ]

        XCTAssertFalse(metadata.isEmpty)
        XCTAssertEqual(metadata.stringDictionary["userId"], "abc123")
        XCTAssertEqual(metadata.stringDictionary["retryCount"], "3")
        XCTAssertEqual(metadata.stringDictionary["latency"], "0.245")
    }

    func testSubscriptGetSet() {
        var metadata = LogMetadata()
        metadata["key"] = "value"
        XCTAssertEqual(metadata.stringDictionary["key"], "value")
    }

    func testSubscriptOverwrite() {
        var metadata = LogMetadata()
        metadata["key"] = "old"
        metadata["key"] = "new"
        XCTAssertEqual(metadata.stringDictionary["key"], "new")
    }

    func testSubscriptRemove() {
        var metadata: LogMetadata = ["key": "value"]
        metadata["key"] = nil
        XCTAssertNil(metadata.stringDictionary["key"])
        XCTAssertTrue(metadata.isEmpty)
    }

    func testCodableInit() {
        struct UserInfo: Codable {
            let name: String
            let age: Int
        }

        let metadata = LogMetadata(codable: UserInfo(name: "Test", age: 25))
        XCTAssertEqual(metadata.stringDictionary["name"], "Test")
        XCTAssertEqual(metadata.stringDictionary["age"], "25")
    }

    func testCodableInitWithArray() {
        let metadata = LogMetadata(codable: [1, 2, 3])
        // Arrays aren't dictionaries, so should fall back to "data" key
        XCTAssertNotNil(metadata.stringDictionary["data"])
    }

    func testIntValues() {
        var metadata = LogMetadata()
        metadata["count"] = 42
        XCTAssertEqual(metadata.stringDictionary["count"], "42")
    }

    func testBoolValues() {
        var metadata = LogMetadata()
        metadata["enabled"] = true
        XCTAssertEqual(metadata.stringDictionary["enabled"], "true")
    }

    func testStringDictionaryOutput() {
        let metadata: LogMetadata = ["a": 1, "b": "two"]
        let dict = metadata.stringDictionary
        XCTAssertEqual(dict.count, 2)
        XCTAssertEqual(dict["a"], "1")
        XCTAssertEqual(dict["b"], "two")
    }
}
