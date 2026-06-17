import XCTest
@testable import EasyLoggingCore
@testable import EasyLoggingNetwork

final class NetworkActivityStoreTests: XCTestCase {

    private func makeRecord(id: UUID = UUID()) -> NetworkRequestRecord {
        NetworkRequestRecord(
            id: id, date: Date(), method: "GET", url: "https://example.com",
            host: "example.com", path: "/", statusCode: 200, duration: 0.1,
            requestHeaders: [:], requestBody: nil, responseHeaders: [:], responseBody: nil,
            errorMessage: nil, requestSize: 0, responseSize: 0
        )
    }

    // MARK: - Store

    func testRecordSnapshotAndClear() {
        let store = NetworkActivityStore()
        store.capacity = 10
        let first = makeRecord(), second = makeRecord()
        store.record(first)
        store.record(second)

        let snapshot = store.snapshot()
        XCTAssertEqual(snapshot.map(\.id), [first.id, second.id], "snapshot is oldest-first")

        store.clear()
        XCTAssertTrue(store.snapshot().isEmpty)
    }

    func testCapacityTrimsOldestFirst() {
        let store = NetworkActivityStore()
        store.capacity = 2
        let first = makeRecord(), second = makeRecord(), third = makeRecord()
        store.record(first)
        store.record(second)
        store.record(third)

        XCTAssertEqual(store.snapshot().map(\.id), [second.id, third.id], "oldest record is dropped past capacity")
    }

    func testLoweringCapacityTrimsExisting() {
        let store = NetworkActivityStore()
        store.capacity = 5
        let records = (0..<5).map { _ in makeRecord() }
        records.forEach(store.record)

        store.capacity = 2
        XCTAssertEqual(store.snapshot().map(\.id), records.suffix(2).map(\.id))
    }

    // MARK: - makeNetworkRecord redaction & body capture

    private func sampleRequest() -> URLRequest {
        var request = URLRequest(url: URL(string: "https://api.example.com/v1/users?token=abc")!)
        request.httpMethod = "POST"
        request.setValue("Bearer secret", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(#"{"name":"a"}"#.utf8)
        return request
    }

    private func sampleResponse() -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: "https://api.example.com/v1/users")!,
            statusCode: 200, httpVersion: nil,
            headerFields: ["Set-Cookie": "session=xyz", "Content-Type": "application/json"]
        )!
    }

    func testNonProductionKeepsHeadersAndBodies() {
        let record = NetworkLogger.makeNetworkRecord(
            request: sampleRequest(), response: sampleResponse(),
            data: Data(#"{"ok":true}"#.utf8), error: nil, duration: 0.2,
            isProduction: false, maxBodyBytes: 1024
        )

        XCTAssertEqual(record.requestHeaders["Authorization"], "Bearer secret")
        XCTAssertEqual(record.responseHeaders["Set-Cookie"], "session=xyz")
        XCTAssertNotNil(record.requestBody)
        XCTAssertNotNil(record.responseBody)
        XCTAssertEqual(record.statusCode, 200)
        XCTAssertEqual(record.host, "api.example.com")
    }

    func testProductionRedactsHeadersAndOmitsBodies() {
        let record = NetworkLogger.makeNetworkRecord(
            request: sampleRequest(), response: sampleResponse(),
            data: Data(#"{"ok":true}"#.utf8), error: nil, duration: 0.2,
            isProduction: true, maxBodyBytes: 1024
        )

        XCTAssertEqual(record.requestHeaders["Authorization"], "<REDACTED>")
        XCTAssertEqual(record.responseHeaders["Set-Cookie"], "<REDACTED>")
        XCTAssertEqual(record.requestHeaders["Content-Type"], "application/json", "non-sensitive headers kept")
        XCTAssertNil(record.requestBody, "bodies are not stored in production")
        XCTAssertNil(record.responseBody)
        // Sizes still reflect the real payloads even when bodies are omitted.
        XCTAssertGreaterThan(record.requestSize, 0)
        XCTAssertGreaterThan(record.responseSize, 0)
    }

    func testBodyTruncatedToCap() {
        let record = NetworkLogger.makeNetworkRecord(
            request: sampleRequest(), response: sampleResponse(),
            data: Data(repeating: 0x41, count: 100), error: nil, duration: 0.1,
            isProduction: false, maxBodyBytes: 10
        )
        XCTAssertEqual(record.responseBody?.count, 10)
        XCTAssertEqual(record.responseSize, 100, "reported size is the original, untruncated length")
    }

    func testFailureFlag() {
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        let record = NetworkLogger.makeNetworkRecord(
            request: sampleRequest(), response: nil, data: nil, error: error,
            duration: 0.1, isProduction: false, maxBodyBytes: 1024
        )
        XCTAssertTrue(record.isFailure)
        XCTAssertEqual(record.statusText, "Error")
        XCTAssertNotNil(record.errorMessage)
    }

    // MARK: - cURL

    func testCurlForGetWithHeader() {
        var request = URLRequest(url: URL(string: "https://example.com/data")!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let record = NetworkLogger.makeNetworkRecord(
            request: request, response: sampleResponse(), data: nil, error: nil,
            duration: 0.1, isProduction: false, maxBodyBytes: 1024
        )
        let curl = record.curlCommand
        XCTAssertTrue(curl.contains("curl -X GET 'https://example.com/data'"))
        XCTAssertTrue(curl.contains("-H 'Accept: application/json'"))
        XCTAssertFalse(curl.contains("--data"))
    }

    func testCurlForPostWithBody() {
        let record = NetworkLogger.makeNetworkRecord(
            request: sampleRequest(), response: sampleResponse(), data: nil, error: nil,
            duration: 0.1, isProduction: false, maxBodyBytes: 1024
        )
        let curl = record.curlCommand
        XCTAssertTrue(curl.contains("curl -X POST"))
        XCTAssertTrue(curl.contains(#"--data '{"name":"a"}'"#))
    }

    // MARK: - Pretty body

    func testPrettyBodyFormatsJSON() {
        let pretty = NetworkRequestRecord.prettyBody(Data(#"{"b":2,"a":1}"#.utf8))
        XCTAssertEqual(pretty, "{\n  \"a\" : 1,\n  \"b\" : 2\n}", "JSON is pretty-printed with sorted keys")
    }

    func testPrettyBodyFallsBackToText() {
        XCTAssertEqual(NetworkRequestRecord.prettyBody(Data("plain text".utf8)), "plain text")
    }

    func testPrettyBodyReportsBinarySize() {
        let binary = Data([0xFF, 0xFE, 0xFD])
        XCTAssertEqual(NetworkRequestRecord.prettyBody(binary), "<3 bytes>")
    }
}
