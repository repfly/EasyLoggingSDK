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
}
