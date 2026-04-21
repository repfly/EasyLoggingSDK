import XCTest
@testable import EasyLoggingSDK

final class RedactionTests: XCTestCase {

    // MARK: - RedactionLevel

    func testAutoRedactsInProduction() {
        var metadata = LogMetadata()
        metadata.setRedactable("secret@mail.com", forKey: "email", redaction: .auto)

        let result = metadata.redactedDictionary(isProduction: true)
        XCTAssertEqual(result["email"], "<REDACTED>")
    }

    func testAutoDoesNotRedactOutsideProduction() {
        var metadata = LogMetadata()
        metadata.setRedactable("secret@mail.com", forKey: "email", redaction: .auto)

        let result = metadata.redactedDictionary(isProduction: false)
        XCTAssertEqual(result["email"], "secret@mail.com")
    }

    func testAlwaysRedactsEverywhere() {
        var metadata = LogMetadata()
        metadata.setRedactable("tok_abc", forKey: "token", redaction: .always)

        let dev = metadata.redactedDictionary(isProduction: false)
        let prod = metadata.redactedDictionary(isProduction: true)

        XCTAssertEqual(dev["token"], "<REDACTED>")
        XCTAssertEqual(prod["token"], "<REDACTED>")
    }

    func testNeverRedacts() {
        var metadata = LogMetadata()
        metadata.setRedactable("public_value", forKey: "tag", redaction: .never)

        let dev = metadata.redactedDictionary(isProduction: false)
        let prod = metadata.redactedDictionary(isProduction: true)

        XCTAssertEqual(dev["tag"], "public_value")
        XCTAssertEqual(prod["tag"], "public_value")
    }

    // MARK: - Mixed metadata

    func testNonRedactableKeysUnaffected() {
        var metadata = LogMetadata()
        metadata["requestId"] = "req_123"
        metadata.setRedactable("user@mail.com", forKey: "email", redaction: .auto)

        let result = metadata.redactedDictionary(isProduction: true)
        XCTAssertEqual(result["requestId"], "req_123")
        XCTAssertEqual(result["email"], "<REDACTED>")
    }

    func testOverwriteRedactableValue() {
        var metadata = LogMetadata()
        metadata.setRedactable("first", forKey: "key", redaction: .auto)
        metadata.setRedactable("second", forKey: "key", redaction: .always)

        let result = metadata.redactedDictionary(isProduction: false)
        XCTAssertEqual(result["key"], "<REDACTED>")
    }

    func testStringDictionaryIgnoresRedaction() {
        var metadata = LogMetadata()
        metadata.setRedactable("secret", forKey: "key", redaction: .always)

        // stringDictionary returns raw values (no redaction applied)
        XCTAssertEqual(metadata.stringDictionary["key"], "secret")
    }
}
