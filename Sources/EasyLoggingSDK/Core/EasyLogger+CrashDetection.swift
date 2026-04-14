//
//  EasyLogger+Setup.swift
//
//

import CocoaLumberjack
import Foundation
import Logging

// MARK: - Logger Initialization & Crash Detection

extension EasyLogger {
    func initializeLogger(with configuration: Configuration) {
        setupConsoleLogging(with: configuration)
        setupFileLogging(with: configuration)
        setupCrashDetection(with: configuration)
        bootstrapLoggingSystemOnce(with: configuration)
    }

    func resetLoggers() {
        DDLog.removeAllLoggers()
        fileLogger = nil
    }

    private func bootstrapLoggingSystemOnce(with configuration: Configuration) {
        Self.bootstrapLock.lock()
        defer { Self.bootstrapLock.unlock() }

        guard !Self.isLoggingSystemBootstrapped else { return }

        let minLevel = configuration.minimumLogLevel
        LoggingSystem.bootstrap { label in
            LumberjackLogHandler(label: label, minimumLogLevel: minLevel)
        }
        Self.isLoggingSystemBootstrapped = true
    }

    private func setupConsoleLogging(with configuration: Configuration) {
        guard configuration.shouldLogToConsole else { return }
        DDLog.add(DDOSLogger.sharedInstance)
    }

    private func setupFileLogging(with configuration: Configuration) {
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

    private func setupCrashDetection(with configuration: Configuration) {
        guard configuration.shouldDetectCrashes else { return }
        setUncaughtExceptionHandler()
        detectPreviousCrash()
    }

    private func setUncaughtExceptionHandler() {
        NSSetUncaughtExceptionHandler { exception in
            EasyLogger.handleException(exception)
        }
    }

    static func handleException(_ exception: NSException) {
        let logger = EasyLogger.shared

        let stack = exception.callStackSymbols.joined(separator: "\n")
        let name = exception.name.rawValue
        let reason = exception.reason ?? "No reason provided"

        let crashReport = String(
            format: LoggingConstants.CrashDetectionMessage.crashDetected,
            name,
            reason,
            stack
        )

        let formattedMessage = LogFormat.default.format(
            message: crashReport,
            level: .error,
            metadata: nil,
            file: #file,
            function: #function,
            line: #line
        )

        withVaList([formattedMessage as NSString]) { args in
            DDLog.log(
                asynchronous: false,
                level: .error,
                flag: .error,
                context: 0,
                file: #file,
                function: #function,
                line: #line,
                tag: nil,
                format: "%@",
                arguments: args
            )
        }

        UserDefaults.standard.set(true, forKey: logger.crashFlagKey)
    }

    func detectPreviousCrash() {
        guard UserDefaults.standard.bool(forKey: crashFlagKey) == true else { return }
        log(LoggingConstants.CrashDetectionMessage.previousCrash, level: .error)
        UserDefaults.standard.set(false, forKey: crashFlagKey)
    }
}
