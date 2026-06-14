import CocoaLumberjack
import Foundation

// MARK: - Convenience Methods

public extension EasyLogger {
    func debug(
        _ message: @autoclosure () -> String,
        category: String? = nil,
        metadata: LogMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message(), level: .debug, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    func info(
        _ message: @autoclosure () -> String,
        category: String? = nil,
        metadata: LogMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message(), level: .info, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    func warning(
        _ message: @autoclosure () -> String,
        category: String? = nil,
        metadata: LogMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message(), level: .warning, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    func error(
        _ message: @autoclosure () -> String,
        category: String? = nil,
        metadata: LogMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message(), level: .error, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    /// Returns whether the given log level is enabled under the current configuration.
    func isEnabled(level: LogLevel) -> Bool {
        level >= self.configuration.minimumLogLevel
    }
}

// MARK: - Internal SDK Logging (Clean Format)

extension EasyLogger {
    func internalDebug(_ message: String, metadata: [String: String]? = nil) {
        guard self.configuration.minimumLogLevel <= .debug else { return }
        logInternalMessage(message, level: .debug, metadata: metadata)
    }

    func internalInfo(_ message: String, metadata: [String: String]? = nil) {
        guard self.configuration.minimumLogLevel <= .info else { return }
        logInternalMessage(message, level: .info, metadata: metadata)
    }

    func internalWarning(_ message: String, metadata: [String: String]? = nil) {
        guard self.configuration.minimumLogLevel <= .warning else { return }
        logInternalMessage(message, level: .warning, metadata: metadata)
    }

    func internalError(_ message: String, metadata: [String: String]? = nil) {
        guard self.configuration.minimumLogLevel <= .error else { return }
        logInternalMessage(message, level: .error, metadata: metadata)
    }

    private func logInternalMessage(_ message: String, level: LogLevel, metadata: [String: String]?) {
        let config = self.configuration
        let record = LogRecord(
            messageString: message,
            level: level,
            category: nil,
            metadata: metadata,
            file: "",
            function: "",
            line: 0,
            config: config,
            isInternal: true
        )
        pipeline.enqueue(.record(record))
    }
}
