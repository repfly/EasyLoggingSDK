import CocoaLumberjack
import Foundation

public extension EasyLogger {
    /// Returns the URL of the current active log file, or nil if file logging is disabled.
    @available(iOS 15.0, macOS 12.0, *)
    func getCurrentLogFileURL() async -> URL? {
        await loggingActor.currentLogFileURL()
    }

    /// Returns the file paths of all rotated log files, newest first.
    func getLogFilePaths() async -> [String] {
        await loggingActor.logFilePaths()
    }

    /// Rotates the current log file, creating a new one.
    func rotateLogFile(completion: (@Sendable () -> Void)? = nil) {
        Task {
            await loggingActor.rotateLogFile()
            completion?()
        }
    }

    /// Removes all log files from disk.
    func removeAllLogFiles() {
        Task {
            await loggingActor.removeAllLogFiles()
        }
    }
}
