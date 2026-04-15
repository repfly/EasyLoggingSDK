//
//  EasyLogger+FileManagement.swift
//
//

import CocoaLumberjack
import Foundation

public extension EasyLogger {
    /// Returns the URL of the current active log file, or nil if file logging is disabled.
    ///
    /// This reads asynchronously from the internal queue, avoiding main thread blocking.
    /// Prefer this over ``currentLogFileURL`` which blocks the caller.
    @available(iOS 15.0, macOS 12.0, *)
    func getCurrentLogFileURL() async -> URL? {
        await withCheckedContinuation { continuation in
            queue.async {
                if let filePath = self.fileLogger?.currentLogFileInfo?.filePath {
                    continuation.resume(returning: URL(fileURLWithPath: filePath))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// Returns the URL of the current active log file synchronously.
    ///
    /// - Warning: This blocks the calling thread until the internal queue is available.
    ///   Avoid calling from the main thread in production code. Prefer ``getCurrentLogFileURL()`` instead.
    var currentLogFileURL: URL? {
        queue.sync {
            if let filePath = self.fileLogger?.currentLogFileInfo?.filePath {
                return URL(fileURLWithPath: filePath)
            }
            return nil
        }
    }

    /// Rotates the current log file, creating a new one.
    ///
    /// - Parameter completion: Called on the internal queue after rotation completes. May be nil.
    func rotateLogFile(completion: (() -> Void)? = nil) {
        queue.async {
            self.fileLogger?.rollLogFile { [weak self] in
                guard let self = self else { return }
                self.internalDebug("Log file rotated successfully")
                completion?()
            }
        }
    }

    /// Removes all log files from disk.
    func removeAllLogFiles() {
        queue.async {
            guard let logFileManager = self.fileLogger?.logFileManager else { return }
            let logFiles = logFileManager.sortedLogFileInfos
            for logFileInfo in logFiles {
                do {
                    try FileManager.default.removeItem(atPath: logFileInfo.filePath)
                } catch {
                    self.internalError(
                        String(format: "Failed to remove log file: %@", error.localizedDescription)
                    )
                }
            }
            self.internalDebug("All log files removed")
        }
    }
}
