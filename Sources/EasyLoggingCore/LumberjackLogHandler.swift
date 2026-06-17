import Logging
import CocoaLumberjack

/// A logging backend that writes to CocoaLumberjack.
///
/// Internal: this is the swift-log backend the SDK bootstraps. It must not be instantiated or
/// installed by consumers, since it writes directly to the SDK's console/file sinks. Routing the
/// swift-log path through the redaction pipeline is tracked for the swift-log bridge work.
///
/// The handler stores its own `logLevel` and `_metadata` as instance state, matching swift-log's
/// value semantics — each `Logger` gets its own copy of the handler with no global side-effects.
/// The SDK's own filtering happens in `EasyLogger.log`, so per-instance handler levels are correct.
struct LumberjackLogHandler: Logging.LogHandler {
    private let label: String
    private var _metadata: Logging.Logger.Metadata
    private var _logLevel: LogLevel

    public init(label: String, minimumLogLevel: LogLevel = .debug) {
        self.label = label
        self._metadata = [:]
        self._logLevel = minimumLogLevel
    }

    // MARK: - LogHandler Protocol

    public var logLevel: Logging.Logger.Level {
        get { _logLevel.toSwiftLogLevel() }
        set { _logLevel = LogLevel(fromSwiftLogLevel: newValue) }
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
    // Delegate to LogLevel so there is exactly ONE swift-log -> CocoaLumberjack mapping, shared
    // with the native logging path (e.g. trace -> .verbose, critical -> .error). Defining it here
    // independently previously drifted (trace mapped to .debug on this path but .verbose natively).
    func toDDLogLevel() -> DDLogLevel { LogLevel(fromSwiftLogLevel: self).ddLogLevel }
    func toDDLogFlag() -> DDLogFlag { LogLevel(fromSwiftLogLevel: self).flag }
}

extension LogLevel {
    func toSwiftLogLevel() -> Logging.Logger.Level {
        switch self {
        case .trace: return .trace
        case .debug: return .debug
        case .info: return .info
        case .warning: return .warning
        case .error: return .error
        case .critical: return .critical
        }
    }

    init(fromSwiftLogLevel level: Logging.Logger.Level) {
        switch level {
        case .trace: self = .trace
        case .debug: self = .debug
        case .info, .notice: self = .info
        case .warning: self = .warning
        case .error: self = .error
        case .critical: self = .critical
        }
    }
}
