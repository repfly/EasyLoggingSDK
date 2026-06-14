import XCTest
@testable import EasyLoggingSDK

/// Asserts the redaction CONTRACT enforced by ``LogMetadata/redactedDictionary(isProduction:)``.
///
/// Redaction must be unbypassable: every public logging path funnels metadata through this
/// single method, so these tests pin down its behavior across environments.
final class RedactionContractTests: XCTestCase {

    /// (a) `.always` redacts in development AND production.
    func testAlwaysRedactsInBothEnvironments() {
        var metadata = LogMetadata()
        metadata.setRedactable("tok_secret", forKey: "token", redaction: .always)

        let dev = metadata.redactedDictionary(isProduction: false)
        let prod = metadata.redactedDictionary(isProduction: true)

        XCTAssertEqual(dev["token"], "<REDACTED>")
        XCTAssertEqual(prod["token"], "<REDACTED>")
    }

    /// (b) `.auto` redacts ONLY in production; plaintext in development.
    func testAutoRedactsOnlyInProduction() {
        var metadata = LogMetadata()
        metadata.setRedactable("user@example.com", forKey: "email", redaction: .auto)

        let dev = metadata.redactedDictionary(isProduction: false)
        let prod = metadata.redactedDictionary(isProduction: true)

        XCTAssertEqual(dev["email"], "user@example.com")
        XCTAssertEqual(prod["email"], "<REDACTED>")
    }

    /// (c) `.never` never redacts, in any environment.
    func testNeverRedactsInAnyEnvironment() {
        var metadata = LogMetadata()
        metadata.setRedactable("public_tag", forKey: "tag", redaction: .never)

        let dev = metadata.redactedDictionary(isProduction: false)
        let prod = metadata.redactedDictionary(isProduction: true)

        XCTAssertEqual(dev["tag"], "public_tag")
        XCTAssertEqual(prod["tag"], "public_tag")
    }

    /// (d) Non-redactable keys pass through unchanged.
    func testNonRedactableKeysPassThroughUnchanged() {
        var metadata = LogMetadata()
        metadata["requestId"] = "req_123"
        metadata["retryCount"] = 3
        metadata["latency"] = 0.245
        metadata["enabled"] = true

        for isProduction in [true, false] {
            let result = metadata.redactedDictionary(isProduction: isProduction)
            XCTAssertEqual(result["requestId"], "req_123")
            XCTAssertEqual(result["retryCount"], "3")
            XCTAssertEqual(result["latency"], "0.245")
            XCTAssertEqual(result["enabled"], "true")
        }
    }

    /// Sensitive-looking keys are auto-redacted by default on EVERY insertion path,
    /// even when the developer never calls `setRedactable` — defense in depth.
    func testSensitiveKeysAutoRedactWithoutExplicitMarking() {
        // Dictionary-literal path.
        let literal: LogMetadata = ["password": "hunter2", "userId": "u_1"]
        // Subscript path.
        var subscripted = LogMetadata()
        subscripted["api_key"] = "sk_live_123"
        subscripted["count"] = 7
        // Codable path.
        struct Creds: Codable { let token: String; let username: String }
        let coded = LogMetadata(codable: Creds(token: "tok_abc", username: "alice"))

        for isProduction in [true, false] {
            XCTAssertEqual(literal.redactedDictionary(isProduction: isProduction)["password"], "<REDACTED>")
            XCTAssertEqual(literal.redactedDictionary(isProduction: isProduction)["userId"], "u_1")

            XCTAssertEqual(subscripted.redactedDictionary(isProduction: isProduction)["api_key"], "<REDACTED>")
            XCTAssertEqual(subscripted.redactedDictionary(isProduction: isProduction)["count"], "7")

            XCTAssertEqual(coded.redactedDictionary(isProduction: isProduction)["token"], "<REDACTED>")
            XCTAssertEqual(coded.redactedDictionary(isProduction: isProduction)["username"], "alice")
        }
    }

    /// An explicit `setRedactable` level always wins over the sensitive-key default.
    func testExplicitRedactionOverridesSensitiveDefault() {
        var metadata = LogMetadata()
        metadata.setRedactable("public-token-ok", forKey: "token", redaction: .never)

        let dev = metadata.redactedDictionary(isProduction: false)
        let prod = metadata.redactedDictionary(isProduction: true)
        XCTAssertEqual(dev["token"], "public-token-ok")
        XCTAssertEqual(prod["token"], "public-token-ok")
    }

    /// Mixed metadata: redactable and non-redactable keys coexist correctly.
    func testMixedMetadataContract() {
        var metadata = LogMetadata()
        metadata["method"] = "GET"
        metadata.setRedactable("https://api.example.com?token=abc", forKey: "url", redaction: .auto)
        metadata.setRedactable("Bearer xyz", forKey: "authorization", redaction: .always)

        let dev = metadata.redactedDictionary(isProduction: false)
        XCTAssertEqual(dev["method"], "GET")
        XCTAssertEqual(dev["url"], "https://api.example.com?token=abc")
        XCTAssertEqual(dev["authorization"], "<REDACTED>")

        let prod = metadata.redactedDictionary(isProduction: true)
        XCTAssertEqual(prod["method"], "GET")
        XCTAssertEqual(prod["url"], "<REDACTED>")
        XCTAssertEqual(prod["authorization"], "<REDACTED>")
    }
}
