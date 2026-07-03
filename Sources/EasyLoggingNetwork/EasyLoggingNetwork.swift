import EasyLoggingCore
import Foundation

/// Entry point for the network feature layer; keeps ``NetworkActivityStore`` in sync with the
/// logger's configuration. `EasyLoggingSDK.activate()` calls ``install(logger:)``; slim builds
/// linking only Core + Network get it implicitly via
/// `EasyLogger.networkLoggingSessionConfiguration()`.
public enum EasyLoggingNetwork {
    /// Wires the shared network activity store into `logger`. Idempotent.
    public static func install(logger: EasyLogger = .shared) {
        logger.register(NetworkStoreIntegration.shared)
    }
}

/// Applies `maxNetworkViewerEntries` to the shared store on every configuration change.
final class NetworkStoreIntegration: EasyLoggerIntegration {
    static let shared = NetworkStoreIntegration()

    func apply(previous: EasyLogger.Configuration?, new: EasyLogger.Configuration) {
        NetworkActivityStore.shared.capacity = new.maxNetworkViewerEntries
    }
}
