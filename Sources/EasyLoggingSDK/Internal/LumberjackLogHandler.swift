import Logging
import CocoaLumberjack

/// Shared minimum log level for all bootstrapped swift-log handlers.
enum SwiftLogConfiguration {
    private static let lock = UnfairLock()
    private static var _minimumLogLevel: LogLevel = .debug

    static var minimumLogLevel: LogLevel {
        get { lock.withLock { _minimumLogLevel } }
        set { lock.withLock { _minimumLogLevel = newValue } }
    }
}

/// A logging backend that writes to CocoaLumberjack
public struct LumberjackLogHandler: Logging.LogHandler {
    private let label: String
    private var _metadata: Logging.Logger.Metadata

    public init(label: String, minimumLogLevel: LogLevel = .debug) {
        self.label = label
        self._metadata = [:]
        SwiftLogConfiguration.minimumLogLevel = minimumLogLevel
    }

    // MARK: - LogHandler Protocol

    public var logLevel: Logging.Logger.Level {
        get { SwiftLogConfiguration.minimumLogLevel.toSwiftLogLevel() }
        set { SwiftLogConfiguration.minimumLogLevel = LogLevel(fromSwiftLogLevel: newValue) }
    }

    public var metadata: Logging.Logger.Metadata {
        get { _metadata }
        set { _metadata = newValue }
    }

    public subscript(metadataKey metadataKey: String) -> Logging.Logger.Metadata.Value? {
        get { _metadata[metadataKey] }
        set { _metadata[metadataKey] = newValue }
    }

    public func log(
        level: Logging.Logger.Level,
        message: Logging.Logger.Message,
        metadata: Logging.Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        let combinedMetadata = metadata?.merging(_metadata) { _, new in new } ?? _metadata
        let prettyMetadata = prettify(combinedMetadata)
        let logMessage = "\(message)\(prettyMetadata.map { " \($0)" } ?? "")"

        let ddLogLevel = level.toDDLogLevel()
        let flag = level.toDDLogFlag()

        withVaList([logMessage as NSString]) { args in
            DDLog.log(
                asynchronous: true,
                level: ddLogLevel,
                flag: flag,
                context: 0,
                file: file,
                function: function,
                line: line,
                tag: label,
                format: "%@",
                arguments: args
            )
        }
    }

    // MARK: - Helper Methods

    private func prettify(_ metadata: Logging.Logger.Metadata) -> String? {
        guard !metadata.isEmpty else { return nil }
        return metadata.map { "[\($0):\($1)]" }.joined(separator: " ")
    }
}

// MARK: - Level Conversion Extensions

private extension Logging.Logger.Level {
    func toDDLogLevel() -> DDLogLevel {
        switch self {
        case .trace, .debug: return .debug
        case .info: return .info
        case .notice, .warning: return .warning
        case .error, .critical: return .error
        }
    }

    func toDDLogFlag() -> DDLogFlag {
        switch self {
        case .trace, .debug: return .debug
        case .info: return .info
        case .notice, .warning: return .warning
        case .error, .critical: return .error
        }
    }
}

extension LogLevel {
    func toSwiftLogLevel() -> Logging.Logger.Level {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .warning
        case .error: return .error
        }
    }

    init(fromSwiftLogLevel level: Logging.Logger.Level) {
        switch level {
        case .trace, .debug: self = .debug
        case .info, .notice: self = .info
        case .warning: self = .warning
        case .error, .critical: self = .error
        }
    }
}
