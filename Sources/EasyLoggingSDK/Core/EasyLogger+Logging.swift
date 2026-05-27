import CocoaLumberjack
import Foundation

// MARK: - Convenience Methods

public extension EasyLogger {
    func debug<T: Codable>(
        _ message: @autoclosure () -> String,
        category: String? = nil,
        metadata: T,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message(), level: .debug, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    func info<T: Codable>(
        _ message: @autoclosure () -> String,
        category: String? = nil,
        metadata: T,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message(), level: .info, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    func warning<T: Codable>(
        _ message: @autoclosure () -> String,
        category: String? = nil,
        metadata: T,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message(), level: .warning, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    func error<T: Codable>(
        _ message: @autoclosure () -> String,
        category: String? = nil,
        metadata: T,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message(), level: .error, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    func debug(
        _ message: @autoclosure () -> String,
        category: String? = nil,
        metadata: [String: Any]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message(), level: .debug, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    func info(
        _ message: @autoclosure () -> String,
        category: String? = nil,
        metadata: [String: Any]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message(), level: .info, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    func warning(
        _ message: @autoclosure () -> String,
        category: String? = nil,
        metadata: [String: Any]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message(), level: .warning, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    func error(
        _ message: @autoclosure () -> String,
        category: String? = nil,
        metadata: [String: Any]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message(), level: .error, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    // MARK: - Typed Metadata Methods

    func debug(
        _ message: @autoclosure () -> String,
        category: String? = nil,
        metadata: LogMetadata,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let dict = metadata.redactedDictionary(isProduction: environment == .production)
        log(message(), level: .debug, category: category, metadata: dict, file: file, function: function, line: line)
    }

    func info(
        _ message: @autoclosure () -> String,
        category: String? = nil,
        metadata: LogMetadata,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let dict = metadata.redactedDictionary(isProduction: environment == .production)
        log(message(), level: .info, category: category, metadata: dict, file: file, function: function, line: line)
    }

    func warning(
        _ message: @autoclosure () -> String,
        category: String? = nil,
        metadata: LogMetadata,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let dict = metadata.redactedDictionary(isProduction: environment == .production)
        log(message(), level: .warning, category: category, metadata: dict, file: file, function: function, line: line)
    }

    func error(
        _ message: @autoclosure () -> String,
        category: String? = nil,
        metadata: LogMetadata,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let dict = metadata.redactedDictionary(isProduction: environment == .production)
        log(message(), level: .error, category: category, metadata: dict, file: file, function: function, line: line)
    }

    /// Returns whether the given log level is enabled under the current configuration.
    func isEnabled(level: LogLevel) -> Bool {
        level >= self.configuration.minimumLogLevel
    }
}

// MARK: - Internal SDK Logging (Clean Format)

extension EasyLogger {
    func internalDebug(_ message: String, metadata: [String: Any]? = nil) {
        guard self.configuration.minimumLogLevel <= .debug else { return }
        logInternalMessage(message, level: .debug, metadata: metadata)
    }

    func internalInfo(_ message: String, metadata: [String: Any]? = nil) {
        guard self.configuration.minimumLogLevel <= .info else { return }
        logInternalMessage(message, level: .info, metadata: metadata)
    }

    func internalInfo<T: Codable>(_ message: String, metadata: T) {
        guard self.configuration.minimumLogLevel <= .info else { return }
        let metadataDict = encodeCodableToMetadata(metadata)
        logInternalMessage(message, level: .info, metadata: metadataDict)
    }

    func internalWarning(_ message: String, metadata: [String: Any]? = nil) {
        guard self.configuration.minimumLogLevel <= .warning else { return }
        logInternalMessage(message, level: .warning, metadata: metadata)
    }

    func internalError(_ message: String, metadata: [String: Any]? = nil) {
        guard self.configuration.minimumLogLevel <= .error else { return }
        logInternalMessage(message, level: .error, metadata: metadata)
    }

    private func logInternalMessage(_ message: String, level: LogLevel, metadata: [String: Any]?) {
        let config = self.configuration
        Task {
            await self.loggingActor.logInternal(
                message: message,
                level: level,
                metadata: metadata,
                config: config
            )
        }
    }
}
