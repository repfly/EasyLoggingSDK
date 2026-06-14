import CocoaLumberjack
import Foundation
import Logging

/// Actor that serializes all log dispatch, file management, and configuration application.
/// Replaces the serial `DispatchQueue` previously used by `EasyLogger`.
actor LoggingActor {

    private(set) var fileLogger: DDFileLogger?
    private var isLoggingSystemBootstrapped = false

    #if canImport(UIKit)
    private weak var logViewer: InAppLogViewer?

    func setLogViewer(_ viewer: InAppLogViewer) {
        self.logViewer = viewer
    }
    #endif

    // MARK: - Log Dispatch

    /// Single serialized entry point for log records. Branches on `record.isInternal` to choose
    /// between the public and clean internal-format paths.
    func process(_ record: LogRecord) {
        if record.isInternal {
            logInternal(
                message: record.messageString,
                level: record.level,
                metadata: record.metadata,
                config: record.config
            )
        } else {
            log(
                messageString: record.messageString,
                level: record.level,
                category: record.category,
                metadata: record.metadata,
                file: record.file,
                function: record.function,
                line: record.line,
                config: record.config
            )
        }
    }

    private func log(
        messageString: String,
        level: LogLevel,
        category: String?,
        metadata: [String: String]?,
        file: String,
        function: String,
        line: Int,
        config: EasyLogger.Configuration
    ) {
        let formattedMessage = config.logFormat.format(
            message: messageString,
            level: level,
            metadata: metadata,
            category: category,
            file: file,
            function: function,
            line: line
        )

        #if canImport(UIKit)
        if config.enableInAppLogViewer {
            logViewer?.addLogEntry(
                message: messageString,
                level: level,
                category: category,
                metadata: metadata
            )
        }
        #endif

        withVaList([formattedMessage as NSString]) { args in
            DDLog.log(
                asynchronous: false,
                level: level.ddLogLevel,
                flag: level.flag,
                context: 0,
                file: file,
                function: function,
                line: UInt(line),
                tag: nil,
                format: "%@",
                arguments: args
            )
        }
    }

    private func logInternal(
        message: String,
        level: LogLevel,
        metadata: [String: String]?,
        config: EasyLogger.Configuration
    ) {
        let formattedMessage = LogFormat.clean.format(
            message: message,
            level: level,
            metadata: metadata,
            category: nil,
            file: "",
            function: "",
            line: 0
        )

        #if canImport(UIKit)
        if config.enableInAppLogViewer {
            logViewer?.addLogEntry(
                message: message,
                level: level,
                metadata: metadata
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

    // MARK: - Configuration

    func applyConfiguration(_ configuration: EasyLogger.Configuration) {
        resetLoggers()
        initializeLogger(with: configuration)
    }

    // MARK: - Logger Initialization

    private func initializeLogger(with configuration: EasyLogger.Configuration) {
        setupConsoleLogging(with: configuration)
        setupFileLogging(with: configuration)
        bootstrapLoggingSystemOnce(with: configuration)
    }

    private func resetLoggers() {
        DDLog.removeAllLoggers()
        fileLogger = nil
    }

    private func bootstrapLoggingSystemOnce(with configuration: EasyLogger.Configuration) {
        guard !isLoggingSystemBootstrapped else { return }

        let minLevel = configuration.minimumLogLevel
        LoggingSystem.bootstrap { label in
            LumberjackLogHandler(label: label, minimumLogLevel: minLevel)
        }
        isLoggingSystemBootstrapped = true
    }

    private func setupConsoleLogging(with configuration: EasyLogger.Configuration) {
        guard configuration.shouldLogToConsole else { return }
        DDLog.add(DDOSLogger.sharedInstance)
    }

    private func setupFileLogging(with configuration: EasyLogger.Configuration) {
        guard configuration.shouldLogToFile else { return }

        let logsDirectory = configuration.logsDirectory ?? DirectoryHelper.getLogDirectory()
        let logFileManager = DDLogFileManagerDefault(logsDirectory: logsDirectory)

        fileLogger = DDFileLogger(logFileManager: logFileManager)
        fileLogger?.logFileManager.maximumNumberOfLogFiles = configuration.maxLogFiles
        fileLogger?.maximumFileSize = configuration.maxFileSize

        if let fileLogger = fileLogger {
            DDLog.add(fileLogger)
        }
    }

    // MARK: - File Management

    func rotateLogFile() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            guard let fileLogger = self.fileLogger else {
                continuation.resume()
                return
            }
            fileLogger.rollLogFile {
                continuation.resume()
            }
        }
    }

    func removeAllLogFiles() {
        guard let logFileManager = fileLogger?.logFileManager else { return }
        let logFiles = logFileManager.sortedLogFileInfos
        for logFileInfo in logFiles {
            do {
                try FileManager.default.removeItem(atPath: logFileInfo.filePath)
            } catch {
                // Continue removing the remaining files, but surface the failure so it is
                // diagnosable. `internalWarning` enqueues onto the serial pipeline and never
                // blocks, so this is safe from inside the actor.
                EasyLogger.shared.internalWarning(
                    "LoggingActor: failed to remove a log file.",
                    metadata: ["error": error.localizedDescription]
                )
            }
        }
    }

    func currentLogFileURL() -> URL? {
        guard let filePath = fileLogger?.currentLogFileInfo?.filePath else { return nil }
        return URL(fileURLWithPath: filePath)
    }

    /// Returns the file paths of all rotated log files, newest first.
    ///
    /// The `DDFileLogger` never leaves the actor; only the resolved paths are returned.
    func logFilePaths() -> [String] {
        fileLogger?.logFileManager.sortedLogFileInfos.map(\.filePath) ?? []
    }

    // MARK: - Crash Detection

    func setupCrashDetection(with configuration: EasyLogger.Configuration) {
        guard configuration.shouldDetectCrashes else { return }
        NSSetUncaughtExceptionHandler { exception in
            EasyLogger.handleException(exception)
        }
    }

    // MARK: - Lifecycle

    func applicationWillTerminate(crashFlagKey: String) {
        UserDefaults.standard.set(false, forKey: crashFlagKey)
    }
}
