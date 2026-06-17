import EasyLoggingCore
import Foundation

public extension EasyLogger {
    /// Returns a `URLSessionConfiguration` with network logging enabled.
    ///
    /// Use this configuration when creating a `URLSession` to automatically log
    /// every request's method, URL, status code, duration, and body sizes.
    ///
    /// ```swift
    /// let config = EasyLogger.shared.networkLoggingSessionConfiguration()
    /// let session = URLSession(configuration: config)
    /// ```
    ///
    /// - Parameter base: The base configuration to extend. Defaults to `.default`.
    /// - Returns: A configuration with ``NetworkLoggerURLProtocol`` prepended to `protocolClasses`.
    func networkLoggingSessionConfiguration(
        base: URLSessionConfiguration = .default
    ) -> URLSessionConfiguration {
        guard configuration.enableNetworkLogging else { return base }

        let config = base
        var protocols = config.protocolClasses ?? []
        protocols.insert(NetworkLoggerURLProtocol.self, at: 0)
        config.protocolClasses = protocols
        return config
    }
}
