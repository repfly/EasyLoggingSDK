//
//  EasyLogger+Logging.swift
//
//

import CocoaLumberjack
import Foundation

// MARK: - Convenience Methods

public extension EasyLogger {
    func debug<T: Codable>(
        _ message: @autoclosure () -> String,
        metadata: T,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message(), level: .debug, metadata: metadata, file: file, function: function, line: line)
    }

    func info<T: Codable>(
        _ message: @autoclosure () -> String,
        metadata: T,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message(), level: .info, metadata: metadata, file: file, function: function, line: line)
    }

    func warning<T: Codable>(
        _ message: @autoclosure () -> String,
        metadata: T,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message(), level: .warning, metadata: metadata, file: file, function: function, line: line)
    }

    func error<T: Codable>(
        _ message: @autoclosure () -> String,
        metadata: T,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message(), level: .error, metadata: metadata, file: file, function: function, line: line)
    }

    func debug(
        _ message: @autoclosure () -> String,
        metadata: [String: Any]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message(), level: .debug, metadata: metadata, file: file, function: function, line: line)
    }

    func info(
        _ message: @autoclosure () -> String,
        metadata: [String: Any]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message(), level: .info, metadata: metadata, file: file, function: function, line: line)
    }

    func warning(
        _ message: @autoclosure () -> String,
        metadata: [String: Any]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message(), level: .warning, metadata: metadata, file: file, function: function, line: line)
    }

    func error(
        _ message: @autoclosure () -> String,
        metadata: [String: Any]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message(), level: .error, metadata: metadata, file: file, function: function, line: line)
    }

    // MARK: - Typed Metadata Methods

    func debug(
        _ message: @autoclosure () -> String,
        metadata: LogMetadata,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message(), level: .debug, metadata: metadata.stringDictionary, file: file, function: function, line: line)
    }

    func info(
        _ message: @autoclosure () -> String,
        metadata: LogMetadata,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message(), level: .info, metadata: metadata.stringDictionary, file: file, function: function, line: line)
    }

    func warning(
        _ message: @autoclosure () -> String,
        metadata: LogMetadata,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message(), level: .warning, metadata: metadata.stringDictionary, file: file, function: function, line: line)
    }

    func error(
        _ message: @autoclosure () -> String,
        metadata: LogMetadata,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message(), level: .error, metadata: metadata.stringDictionary, file: file, function: function, line: line)
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

    func logInternalMessage(_ message: String, level: LogLevel, metadata: [String: Any]?) {
        queue.async {
            let formattedMessage = LogFormat.clean.format(
                message: message,
                level: level,
                metadata: metadata?.mapValues { String(describing: $0) },
                file: "",
                function: "",
                line: 0
            )

            #if canImport(UIKit)
            let config = self._configuration
            if config.enableInAppLogViewer {
                self.logViewer.addLogEntry(
                    message: message,
                    level: level,
                    metadata: metadata?.mapValues { String(describing: $0) }
                )
            }
            #endif

            withVaList([formattedMessage as NSString]) { args in
                DDLog.log(
                    asynchronous: false,
                    level: level.ddLogLevel,
                    flag: level.flag,
                    context: 0,
                    file: "",
                    function: "",
                    line: 0,
                    tag: nil,
                    format: "%@",
                    arguments: args
                )
            }
        }
    }
}
