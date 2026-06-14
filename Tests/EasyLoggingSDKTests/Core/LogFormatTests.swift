import XCTest
@testable import EasyLoggingSDK

final class LogFormatTests: XCTestCase {

    // MARK: - Default Format

    func testDefaultFormatContainsAllComponents() {
        let result = LogFormat.default.format(
            message: "Test message",
            level: .info,
            metadata: nil,
            category: nil,
            file: "TestFile.swift",
            function: "testFunc()",
            line: 42
        )

        XCTAssertTrue(result.contains("INFO"))
        XCTAssertTrue(result.contains("TestFile.swift"))
        XCTAssertTrue(result.contains("42"))
        XCTAssertTrue(result.contains("testFunc()"))
        XCTAssertTrue(result.contains("Test message"))
    }

    // MARK: - Simple Format

    func testSimpleFormat() {
        let result = LogFormat.simple.format(
            message: "Hello",
            level: .debug,
            metadata: nil,
            category: nil,
            file: "",
            function: "",
            line: 0
        )

        XCTAssertTrue(result.contains("DEBUG"))
        XCTAssertTrue(result.contains("Hello"))
        XCTAssertFalse(result.contains("0")) // Line not in simple format
    }

    // MARK: - Detailed Format

    func testDetailedFormatIncludesTimestamp() {
        let result = LogFormat.detailed.format(
            message: "Detailed test",
            level: .warning,
            metadata: nil,
            category: nil,
            file: "File.swift",
            function: "func()",
            line: 1
        )

        // Should contain ISO8601 timestamp (year)
        let year = Calendar.current.component(.year, from: Date())
        XCTAssertTrue(result.contains(String(year)))
        XCTAssertTrue(result.contains("WARNING"))
        XCTAssertTrue(result.contains("Detailed test"))
    }

    // MARK: - JSON Format

    private func parseJSON(_ string: String) -> [String: Any]? {
        guard let data = string.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    func testJSONFormatProducesValidJSON() {
        let result = LogFormat.json.format(
            message: "JSON test",
            level: .error,
            metadata: nil,
            category: nil,
            file: "/path/to/Test.swift",
            function: "testJSON()",
            line: 10
        )

        guard let object = parseJSON(result) else {
            XCTFail("Output is not valid JSON: \(result)")
            return
        }

        XCTAssertEqual(object["level"] as? String, "error")
        XCTAssertEqual(object["message"] as? String, "JSON test")
        XCTAssertEqual(object["file"] as? String, "Test.swift")
        XCTAssertEqual(object["line"] as? Int, 10)
        XCTAssertEqual(object["function"] as? String, "testJSON()")
        XCTAssertNotNil(object["timestamp"] as? String)
        // Optional fields omitted when absent.
        XCTAssertNil(object["category"])
        XCTAssertNil(object["metadata"])
    }

    func testJSONFormatIncludesCategoryAndMetadataWhenPresent() {
        let result = LogFormat.json.format(
            message: "msg",
            level: .info,
            metadata: ["userId": "42"],
            category: "networking",
            file: "File.swift",
            function: "f()",
            line: 1
        )

        guard let object = parseJSON(result) else {
            XCTFail("Output is not valid JSON: \(result)")
            return
        }

        XCTAssertEqual(object["category"] as? String, "networking")
        let metadata = object["metadata"] as? [String: String]
        XCTAssertEqual(metadata?["userId"], "42")
    }

    func testJSONFormatEscapesHostileContent() {
        let hostileMessage = "He said \"hi\"\n\\path"
        let hostileMetadataValue = "quote\" backslash\\ newline\n"

        let result = LogFormat.json.format(
            message: hostileMessage,
            level: .warning,
            metadata: ["danger": hostileMetadataValue],
            category: "a\"b",
            file: "File.swift",
            function: "f()",
            line: 5
        )

        guard let object = parseJSON(result) else {
            XCTFail("Hostile output is not valid JSON: \(result)")
            return
        }

        // Round-trips exactly through valid JSON.
        XCTAssertEqual(object["message"] as? String, hostileMessage)
        XCTAssertEqual(object["category"] as? String, "a\"b")
        let metadata = object["metadata"] as? [String: String]
        XCTAssertEqual(metadata?["danger"], hostileMetadataValue)
    }

    // MARK: - Clean Format

    func testCleanFormatOmitsFileAndLine() {
        let result = LogFormat.clean.format(
            message: "Clean test",
            level: .info,
            metadata: nil,
            category: nil,
            file: "SomeFile.swift",
            function: "someFunc()",
            line: 99
        )

        XCTAssertTrue(result.contains("INFO"))
        XCTAssertTrue(result.contains("Clean test"))
        // Clean format should not include file/function/line placeholders
    }

    // MARK: - Metadata

    func testMetadataFormatting() {
        let metadata = ["key1": "value1", "key2": "value2"]
        let result = LogFormat.default.format(
            message: "Meta test",
            level: .debug,
            metadata: metadata,
            category: nil,
            file: "File.swift",
            function: "f()",
            line: 1
        )

        XCTAssertTrue(result.contains("[key1:value1]") || result.contains("[key2:value2]"))
    }

    func testEmptyMetadata() {
        let result = LogFormat.default.format(
            message: "No metadata",
            level: .info,
            metadata: [:],
            category: nil,
            file: "File.swift",
            function: "f()",
            line: 1
        )

        XCTAssertTrue(result.contains("No metadata"))
    }

    func testNilMetadata() {
        let result = LogFormat.default.format(
            message: "Nil metadata",
            level: .info,
            metadata: nil,
            category: nil,
            file: "File.swift",
            function: "f()",
            line: 1
        )

        XCTAssertTrue(result.contains("Nil metadata"))
    }

    // MARK: - Custom Template

    func testCustomTemplate() {
        let format = LogFormat(template: "%level | %message")
        let result = format.format(
            message: "Custom",
            level: .error,
            metadata: nil,
            category: nil,
            file: "",
            function: "",
            line: 0
        )

        XCTAssertTrue(result.contains("ERROR"))
        XCTAssertTrue(result.contains("Custom"))
        XCTAssertTrue(result.contains("|"))
    }

    // MARK: - Level Raw in Format

    func testLevelRawUsesStringValue() {
        let format = LogFormat(template: "%levelRaw")
        let result = format.format(
            message: "",
            level: .warning,
            metadata: nil,
            category: nil,
            file: "",
            function: "",
            line: 0
        )

        XCTAssertEqual(result, "warning")
    }

    // MARK: - File Path Extraction

    func testFilePathExtractsLastComponent() {
        let result = LogFormat.default.format(
            message: "test",
            level: .info,
            metadata: nil,
            category: nil,
            file: "/Users/dev/project/Sources/MyFile.swift",
            function: "f()",
            line: 1
        )

        XCTAssertTrue(result.contains("MyFile.swift"))
        XCTAssertFalse(result.contains("/Users/dev"))
    }

    // MARK: - Category

    func testCategoryPlaceholder() {
        let format = LogFormat(template: "[%category] %message")
        let result = format.format(
            message: "test",
            level: .info,
            metadata: nil,
            category: "networking",
            file: "",
            function: "",
            line: 0
        )

        XCTAssertEqual(result, "[networking] test")
    }

    func testNilCategoryProducesEmptyString() {
        let format = LogFormat(template: "[%category] %message")
        let result = format.format(
            message: "test",
            level: .info,
            metadata: nil,
            category: nil,
            file: "",
            function: "",
            line: 0
        )

        XCTAssertEqual(result, "[] test")
    }

    // MARK: - Single-Pass No Corruption

    func testMessageContainingPlaceholderTokensIsNotSubstituted() {
        let format = LogFormat(template: "%message")
        let result = format.format(
            message: "user typed %level and %message",
            level: .error,
            metadata: nil,
            category: nil,
            file: "",
            function: "",
            line: 0
        )

        XCTAssertEqual(result, "user typed %level and %message")
    }

    func testMetadataValueContainingPlaceholderIsNotSubstituted() {
        let format = LogFormat(template: "%metadata")
        let result = format.format(
            message: "",
            level: .info,
            metadata: ["k": "%date"],
            category: nil,
            file: "",
            function: "",
            line: 0
        )

        XCTAssertEqual(result, "[k:%date]")
    }

    func testCategoryValueContainingPlaceholderIsNotSubstituted() {
        let format = LogFormat(template: "%category - %message")
        let result = format.format(
            message: "real",
            level: .info,
            metadata: nil,
            category: "%message",
            file: "",
            function: "",
            line: 0
        )

        XCTAssertEqual(result, "%message - real")
    }

    // MARK: - Longest Match

    func testLongestMatchResolvesLevelRawNotLevel() {
        let format = LogFormat(template: "%levelRaw")
        let result = format.format(
            message: "",
            level: .warning,
            metadata: nil,
            category: nil,
            file: "",
            function: "",
            line: 0
        )

        // Must be the raw name, never "<emoji NAME>Raw".
        XCTAssertEqual(result, "warning")
    }

    func testUnknownTokenIsEmittedVerbatim() {
        let format = LogFormat(template: "%unknown %message")
        let result = format.format(
            message: "hi",
            level: .info,
            metadata: nil,
            category: nil,
            file: "",
            function: "",
            line: 0
        )

        XCTAssertEqual(result, "%unknown hi")
    }
}
