import Foundation

/// Helper class for managing log directories
enum DirectoryHelper {
    /// Returns the directory path for storing log files
    /// - Returns: The path to the log directory
    static func getLogDirectory() -> String {
        let fileManager = FileManager.default
        guard let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return NSTemporaryDirectory()
        }
        var logDirectory = cachesDirectory.appendingPathComponent(LoggingConstants.FileSystem.defaultLogDirectory)

        do {
            if !fileManager.fileExists(atPath: logDirectory.path) {
                try fileManager.createDirectory(
                    at: logDirectory,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            }

            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try logDirectory.setResourceValues(resourceValues)

            applyFileProtection(to: logDirectory, fileManager: fileManager)

            return logDirectory.path
        } catch {
            // Surface the failure instead of swallowing it silently; logging is non-blocking
            // (enqueued onto the SDK's serial pipeline) so it cannot deadlock or block here.
            EasyLogger.shared.internalWarning(
                "DirectoryHelper: failed to prepare log directory; falling back to temporary directory.",
                metadata: ["error": error.localizedDescription]
            )

            let tempDirectory = NSTemporaryDirectory()
            let fallbackPath = (tempDirectory as NSString).appendingPathComponent(LoggingConstants.FileSystem.defaultLogDirectory)

            do {
                try fileManager.createDirectory(
                    atPath: fallbackPath,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            } catch {
                EasyLogger.shared.internalWarning(
                    "DirectoryHelper: failed to create fallback log directory.",
                    metadata: ["error": error.localizedDescription]
                )
            }

            return fallbackPath
        }
    }

    /// Applies file data protection so log files are encrypted at rest on iOS.
    ///
    /// Uses `.completeUntilFirstUserAuthentication`, which keeps logs writable after the first
    /// device unlock (appropriate for background logging) while still encrypting them at rest.
    /// File protection is iOS-only; the attribute is unavailable/ignored on macOS, so the call is
    /// compiled out elsewhere to keep the macOS build clean.
    private static func applyFileProtection(to directory: URL, fileManager: FileManager) {
        #if os(iOS)
        do {
            try fileManager.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: directory.path
            )
        } catch {
            EasyLogger.shared.internalWarning(
                "DirectoryHelper: failed to apply file data protection to log directory.",
                metadata: ["error": error.localizedDescription]
            )
        }
        #endif
    }
}
