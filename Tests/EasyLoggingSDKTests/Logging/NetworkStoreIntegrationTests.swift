import XCTest
@testable import EasyLoggingCore
@testable import EasyLoggingNetwork

final class NetworkStoreIntegrationTests: XCTestCase {

    func testInstallAppliesConfiguredCapacityToSharedStore() {
        let logger = EasyLogger.shared
        EasyLoggingNetwork.install(logger: logger)

        var config = EasyLogger.Configuration()
        config.maxNetworkViewerEntries = 123
        logger.configure(config)
        XCTAssertEqual(NetworkActivityStore.shared.capacity, 123)

        config.maxNetworkViewerEntries = 45
        logger.configure(config)
        XCTAssertEqual(NetworkActivityStore.shared.capacity, 45, "capacity follows configuration changes")
    }

    func testSessionConfigurationSelfInstallsStoreIntegration() {
        let logger = EasyLogger.shared

        var config = EasyLogger.Configuration()
        config.maxNetworkViewerEntries = 77
        logger.configure(config)

        // A slim Core+Network consumer never calls activate()/install(); requesting the session
        // configuration must be enough for the configured capacity to reach the store.
        _ = logger.networkLoggingSessionConfiguration()
        XCTAssertEqual(NetworkActivityStore.shared.capacity, 77)
    }
}
