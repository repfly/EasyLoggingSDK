import XCTest
@testable import EasyLoggingSDK

final class NetworkLoggerTests: XCTestCase {

    // MARK: - URLSessionConfiguration

    func testNetworkLoggingSessionConfigurationInsertsProtocol() {
        let logger = EasyLogger.shared
        let config = logger.networkLoggingSessionConfiguration()

        let protocolClasses = config.protocolClasses ?? []
        let containsNetworkLogger = protocolClasses.contains { $0 == NetworkLoggerURLProtocol.self }
        XCTAssertTrue(containsNetworkLogger, "NetworkLoggerURLProtocol should be in protocolClasses")
    }

    func testNetworkLoggingSessionConfigurationPreservesExistingProtocols() {
        let base = URLSessionConfiguration.default
        let originalCount = (base.protocolClasses ?? []).count

        let logger = EasyLogger.shared
        let config = logger.networkLoggingSessionConfiguration(base: base)
        let newCount = (config.protocolClasses ?? []).count

        XCTAssertEqual(newCount, originalCount + 1)
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
}
