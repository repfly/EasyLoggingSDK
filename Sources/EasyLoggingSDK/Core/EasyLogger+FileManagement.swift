import CocoaLumberjack
import Foundation

public extension EasyLogger {
    /// Returns the URL of the current active log file, or nil if file logging is disabled.
    @available(iOS 15.0, macOS 12.0, *)
    func getCurrentLogFileURL() async -> URL? {
        await loggingActor.currentLogFileURL()
    }

    /// Returns the URL of the current active log file synchronously.
    ///
    /// - Warning: This triggers an async call internally. For non-blocking access,
    ///   prefer ``getCurrentLogFileURL()`` instead.
    var currentLogFileURL: URL? {
        var result: URL?
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            result = await loggingActor.currentLogFileURL()
            semaphore.signal()
        }
        semaphore.wait()
        return result
    }

    /// Rotates the current log file, creating a new one.
    func rotateLogFile(completion: (() -> Void)? = nil) {
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
