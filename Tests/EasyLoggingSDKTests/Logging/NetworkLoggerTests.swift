import XCTest
@testable import EasyLoggingSDK

final class NetworkLoggerTests: XCTestCase {

    // MARK: - URLSessionConfiguration

    func testNetworkLoggingSessionConfigurationInsertsProtocol() {
        var config = EasyLogger.Configuration()
        config.enableNetworkLogging = true
        EasyLogger.shared.configure(config)

        let configWithLogging = EasyLogger.shared.networkLoggingSessionConfiguration()

        let protocolClasses = configWithLogging.protocolClasses ?? []
        let containsNetworkLogger = protocolClasses.contains { $0 == NetworkLoggerURLProtocol.self }
        XCTAssertTrue(containsNetworkLogger, "NetworkLoggerURLProtocol should be in protocolClasses")
    }

    func testNetworkLoggingSessionConfigurationPreservesExistingProtocols() {
        var loggerConfig = EasyLogger.Configuration()
        loggerConfig.enableNetworkLogging = true
        EasyLogger.shared.configure(loggerConfig)

        let base = URLSessionConfiguration.default
        let originalCount = (base.protocolClasses ?? []).count

        let config = EasyLogger.shared.networkLoggingSessionConfiguration(base: base)
        let newCount = (config.protocolClasses ?? []).count

        XCTAssertEqual(newCount, originalCount + 1)
    }

    func testNetworkLoggingSessionConfigurationSkipsProtocolWhenDisabled() {
        var config = EasyLogger.Configuration()
        config.enableNetworkLogging = false
        EasyLogger.shared.configure(config)

        let base = URLSessionConfiguration.default
        let originalCount = (base.protocolClasses ?? []).count

        let configWithoutLogging = EasyLogger.shared.networkLoggingSessionConfiguration(base: base)
        let newCount = (configWithoutLogging.protocolClasses ?? []).count

        XCTAssertEqual(newCount, originalCount)
        XCTAssertFalse(
            (configWithoutLogging.protocolClasses ?? []).contains { $0 == NetworkLoggerURLProtocol.self }
        )
    }

    // MARK: - URLProtocol canInit

    func testCanInitReturnsTrueForNewRequest() {
        let request = URLRequest(url: URL(string: "https://example.com")!)
        XCTAssertTrue(NetworkLoggerURLProtocol.canInit(with: request))
    }

    func testCanInitReturnsFalseForHandledRequest() {
        let url = URL(string: "https://example.com")!
        let mutable = NSMutableURLRequest(url: url)
        URLProtocol.setProperty(true, forKey: "dev.alpr.EasyLoggingSDK.NetworkLoggerHandled", in: mutable)

        XCTAssertFalse(NetworkLoggerURLProtocol.canInit(with: mutable as URLRequest))
    }

    func testCanonicalRequestReturnsIdentity() {
        let request = URLRequest(url: URL(string: "https://example.com/path")!)
        let canonical = NetworkLoggerURLProtocol.canonicalRequest(for: request)
        XCTAssertEqual(canonical, request)
    }

    // MARK: - Configuration flag

    func testEnableNetworkLoggingDefaultsToFalse() {
        let config = EasyLogger.Configuration()
        XCTAssertFalse(config.enableNetworkLogging)
    }

    // MARK: - Log entry building (raw sizes, redaction, safe URL)

    func testLogEntryUsesRawIntByteCounts() {
        var request = URLRequest(url: URL(string: "https://example.com/upload")!)
        request.httpMethod = "POST"
        request.httpBody = Data("hello world!".utf8) // 12 bytes

        let responseData = Data("ok".utf8) // 2 bytes
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        let entry = NetworkLogger.makeLogEntry(
            request: request,
            response: response,
            data: responseData,
            error: nil,
            duration: 0.123
        )

        // LogMetadata stringifies typed values; raw Int counts become plain numeric strings.
        let dict = entry.metadata.redactedDictionary(isProduction: false)
        XCTAssertEqual(dict["request_size"], "12")
        XCTAssertEqual(dict["response_size"], "2")
        XCTAssertEqual(dict["status_code"], "200")
        XCTAssertEqual(dict["method"], "POST")
    }

    func testLogEntryRawSizesAreZeroWhenNoBodyOrData() {
        let request = URLRequest(url: URL(string: "https://example.com/")!)

        let entry = NetworkLogger.makeLogEntry(
            request: request,
            response: nil,
            data: nil,
            error: nil,
            duration: 0
        )

        let dict = entry.metadata.redactedDictionary(isProduction: false)
        XCTAssertEqual(dict["request_size"], "0")
        XCTAssertEqual(dict["response_size"], "0")
    }

    /// A tokened URL must keep the FULL URL only in redactable `url` metadata, while the
    /// message carries a safe, query-stripped URL. (Phase 1 behavior; locked down here.)
    func testTokenedURLKeepsFullURLOnlyInRedactableMetadata() {
        let tokenedURL = URL(string: "https://api.example.com/data?token=SECRET123&page=2")!
        let request = URLRequest(url: tokenedURL)
        let response = HTTPURLResponse(url: tokenedURL, statusCode: 200, httpVersion: nil, headerFields: nil)

        let entry = NetworkLogger.makeLogEntry(
            request: request,
            response: response,
            data: Data(),
            error: nil,
            duration: 0.01
        )

        // The message must NOT contain the query string / token.
        XCTAssertFalse(entry.message.contains("token=SECRET123"), "message must not leak the token")
        XCTAssertFalse(entry.message.contains("?"), "message must be query-stripped")
        XCTAssertTrue(entry.message.contains("https://api.example.com/data"))

        // Development: full URL (with token) is visible in metadata.
        let dev = entry.metadata.redactedDictionary(isProduction: false)
        XCTAssertEqual(dev["url"], tokenedURL.absoluteString)

        // Production: the full URL is redacted.
        let prod = entry.metadata.redactedDictionary(isProduction: true)
        XCTAssertEqual(prod["url"], "<REDACTED>")
    }

    func testLogEntryRedactsAuthorizationHeader() {
        var request = URLRequest(url: URL(string: "https://api.example.com/secure")!)
        request.setValue("Bearer abc.def.ghi", forHTTPHeaderField: "Authorization")
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)

        let entry = NetworkLogger.makeLogEntry(
            request: request,
            response: response,
            data: Data(),
            error: nil,
            duration: 0.01
        )

        let prod = entry.metadata.redactedDictionary(isProduction: true)
        XCTAssertEqual(prod["authorization"], "<REDACTED>")
        XCTAssertFalse(entry.message.contains("Bearer"))
    }

    func testLogEntryDurationIsRespected() {
        let request = URLRequest(url: URL(string: "https://example.com/")!)
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)

        let entry = NetworkLogger.makeLogEntry(
            request: request,
            response: response,
            data: Data(),
            error: nil,
            duration: 0.25 // 250 ms
        )

        let dict = entry.metadata.redactedDictionary(isProduction: false)
        XCTAssertEqual(dict["duration_ms"], "250.0")
    }

    func testRequestCompletedAcceptsDurationAndLogs() async {
        // Exercises the actor entry point with the new `duration` parameter end-to-end.
        let request = URLRequest(url: URL(string: "https://example.com/ping")!)
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)

        await NetworkLogger.shared.requestCompleted(
            request,
            response: response,
            data: Data("pong".utf8),
            error: nil,
            duration: 0.05
        )
        // No crash / no shared timing state required; reaching here is the assertion.
    }
}
