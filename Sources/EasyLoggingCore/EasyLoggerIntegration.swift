import Foundation

/// A receiver for log records, registered via ``EasyLogger/registerLogSink(_:)``.
public protocol LogSink: AnyObject, Sendable {
    // Called synchronously from the logging actor's context, so it must be nonisolated.
    func addLogEntry(message: String, level: LogLevel, category: String?, metadata: [String: String]?)
}

/// A feature that reacts to configuration changes, registered via ``EasyLogger/register(_:)``.
public protocol EasyLoggerIntegration: AnyObject, Sendable {
    /// `previous` is `nil` on the initial replay at registration.
    func apply(previous: EasyLogger.Configuration?, new: EasyLogger.Configuration)
}
