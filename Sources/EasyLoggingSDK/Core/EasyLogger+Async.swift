//
//  EasyLogger+Async.swift
//
//
//  Created by Yildirim, Alper on 19.08.2024.
//

import Foundation

@available(iOS 15.0, macOS 12.0, *)
public extension EasyLogger {
    /// Asynchronously rotates the current log file
    func rotateLogFileAsync() async {
        await withCheckedContinuation { continuation in
            rotateLogFile {
                continuation.resume()
            }
        }
    }

    /// Asynchronously removes all log files
    func removeAllLogFilesAsync() async {
        await withCheckedContinuation { continuation in
            self.performOnInternalQueue {
                self.removeAllLogFiles()
                continuation.resume()
            }
        }
    }

    /// Asynchronously logs a message with the specified level and metadata
    func logAsync(
        _ message: @autoclosure () -> String,
        level: LogLevel = .info,
        category: String? = nil,
        metadata: [String: Any]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) async {
        let evaluatedMessage = message()
        await withCheckedContinuation { continuation in
            self.performOnInternalQueue {
                self.log(
                    evaluatedMessage,
                    level: level,
                    category: category,
                    metadata: metadata,
                    file: file,
                    function: function,
                    line: line
                )
                continuation.resume()
            }
        }
    }

    /// Asynchronously logs a debug message
    func debugAsync(
        _ message: @autoclosure () -> String,
        category: String? = nil,
        metadata: [String: Any]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) async {
        await logAsync(
            message(),
            level: .debug,
            category: category,
            metadata: metadata,
            file: file,
            function: function,
            line: line
        )
    }

    /// Asynchronously logs an info message
    func infoAsync(
        _ message: @autoclosure () -> String,
        category: String? = nil,
        metadata: [String: Any]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) async {
        await logAsync(
            message(),
            level: .info,
            category: category,
            metadata: metadata,
            file: file,
            function: function,
            line: line
        )
    }

    /// Asynchronously logs a warning message
    func warningAsync(
        _ message: @autoclosure () -> String,
        category: String? = nil,
        metadata: [String: Any]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) async {
        await logAsync(
            message(),
            level: .warning,
            category: category,
            metadata: metadata,
            file: file,
            function: function,
            line: line
        )
    }

    /// Asynchronously logs an error message
    func errorAsync(
        _ message: @autoclosure () -> String,
        category: String? = nil,
        metadata: [String: Any]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) async {
        await logAsync(
            message(),
            level: .error,
            category: category,
            metadata: metadata,
            file: file,
            function: function,
            line: line
        )
    }

    /// Asynchronously configures the logger
    func configureAsync(_ configuration: Configuration) async {
        await withCheckedContinuation { continuation in
            self.performOnInternalQueue {
                self.configure(configuration)
                continuation.resume()
            }
        }
    }

    /// Asynchronously sets up the environment
    func setupEnvironmentAsync(
        _ environment: LogEnvironment,
        customConfiguration: Configuration? = nil
    ) async {
        await withCheckedContinuation { continuation in
            self.performOnInternalQueue {
                self.setupEnvironment(environment, customConfiguration: customConfiguration)
                continuation.resume()
            }
        }
    }
}
