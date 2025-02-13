//
//  EasyLogger+Async.swift
//
//
//  Created by Yildirim, Alper on 19.08.2024.
//

import Foundation

@available(iOS 13.0, *)
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
            queue.async {
                self.removeAllLogFiles()
                continuation.resume()
            }
        }
    }
    
    /// Asynchronously logs a message with the specified level and metadata
    func logAsync(
        _ message: @autoclosure () -> String,
        level: LogLevel = .info,
        metadata: [String: Any]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) async {
        await withCheckedContinuation { continuation in
            log(
                message(),
                level: level,
                metadata: metadata,
                file: file,
                function: function,
                line: line
            )
            continuation.resume()
        }
    }
    
    /// Asynchronously logs a debug message
    func debugAsync(
        _ message: @autoclosure () -> String,
        metadata: [String: Any]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) async {
        await logAsync(
            message(),
            level: .debug,
            metadata: metadata,
            file: file,
            function: function,
            line: line
        )
    }
    
    /// Asynchronously logs an info message
    func infoAsync(
        _ message: @autoclosure () -> String,
        metadata: [String: Any]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) async {
        await logAsync(
            message(),
            level: .info,
            metadata: metadata,
            file: file,
            function: function,
            line: line
        )
    }
    
    /// Asynchronously logs a warning message
    func warningAsync(
        _ message: @autoclosure () -> String,
        metadata: [String: Any]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) async {
        await logAsync(
            message(),
            level: .warning,
            metadata: metadata,
            file: file,
            function: function,
            line: line
        )
    }
    
    /// Asynchronously logs an error message
    func errorAsync(
        _ message: @autoclosure () -> String,
        metadata: [String: Any]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) async {
        await logAsync(
            message(),
            level: .error,
            metadata: metadata,
            file: file,
            function: function,
            line: line
        )
    }
    
    /// Asynchronously starts monitoring an object for memory leaks
    func monitorForLeaksAsync(_ target: AnyObject, identifier: String? = nil) async {
        await withCheckedContinuation { continuation in
            queue.async {
                self.monitorForLeaks(target, identifier: identifier)
                continuation.resume()
            }
        }
    }
    
    /// Asynchronously stops monitoring an object for memory leaks
    func stopMonitoringForLeaksAsync(_ target: AnyObject) async {
        await withCheckedContinuation { continuation in
            queue.async {
                self.stopMonitoringForLeaks(target)
                continuation.resume()
            }
        }
    }
    
    /// Asynchronously tracks screen appearance
    func trackScreenAppearanceAsync(_ viewController: UIViewController) async {
        await withCheckedContinuation { continuation in
            queue.async {
                self.trackScreenAppearance(viewController)
                continuation.resume()
            }
        }
    }
    
    /// Asynchronously ends screen tracking and returns the duration
    func endScreenTrackingAsync(_ viewController: UIViewController) async -> TimeInterval? {
        await withCheckedContinuation { continuation in
            queue.async {
                let duration = self.screenTimeTracker.endScreenTracking(viewController)
                continuation.resume(returning: duration)
            }
        }
    }
    
    /// Asynchronously clears all screen time tracking data
    func clearScreenTrackingAsync() async {
        await withCheckedContinuation { continuation in
            queue.async {
                self.clearScreenTimeTracking()
                continuation.resume()
            }
        }
    }
    
    /// Asynchronously configures the logger
    func configureAsync(_ configuration: Configuration) async {
        await withCheckedContinuation { continuation in
            queue.async {
                self.configure(configuration)
                continuation.resume()
            }
        }
    }
    
    /// Asynchronously sets up the environment
    func setupEnvironmentAsync(
        _ environment: Environment,
        customConfiguration: Configuration? = nil
    ) async {
        await withCheckedContinuation { continuation in
            queue.async {
                self.setupEnvironment(environment, customConfiguration: customConfiguration)
                continuation.resume()
            }
        }
    }
} 
