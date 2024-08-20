struct LoggingConfiguration {
    let filename: String
}

import CocoaLumberjack
import Foundation

public class Logger {
    public static let shared = Logger()

    private let crashFlagKey = "wasAppCrashed"

    private init() {
        DDLog.add(DDOSLogger.sharedInstance)
        setUncaughtExceptionHandler()
        detectPreviousCrash()
    }

    // MARK: - Crash Detection

    private func setUncaughtExceptionHandler() {
        NSSetUncaughtExceptionHandler { exception in
            let stack = exception.callStackSymbols.joined(separator: "\n")
            let name = exception.name.rawValue
            let reason = exception.reason ?? "No reason"
            let crashReport = """
            Exception: \(name)
            Reason: \(reason)
            Stack Trace:
            \(stack)
            """
            Logger.shared.log(crashReport, level: .error)
        }
    }

    private func detectPreviousCrash() {
        if UserDefaults.standard.bool(forKey: crashFlagKey) {
            log("App crashed in the previous session.", level: .error)
        }
        // Set the flag to indicate the app is running
        UserDefaults.standard.set(true, forKey: crashFlagKey)
    }

    public func applicationWillTerminate() {
        // Clear the flag as the app is terminating normally
        UserDefaults.standard.set(false, forKey: crashFlagKey)
    }

    // MARK: - Logging

    public func configureFileLogger(logsDirectory: String) {
        let fileManager = DDLogFileManagerDefault(logsDirectory: logsDirectory)
        let fileLogger = DDFileLogger(logFileManager: fileManager)
        fileLogger.rollingFrequency = TimeInterval(60 * 60 * 24)
        fileLogger.logFileManager.maximumNumberOfLogFiles = 7

        DDLog.add(fileLogger)
    }

    public func log(
        _ message: String,
        level: LogLevel = .info,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let timestamp = Date()
        let formattedMessage = "\(level.logDescriptionPrefix) \(fileName(from: file)):\(line) \(function) - \(message)"

        let logMessage = DDLogMessage(
            message: formattedMessage,
            level: level.ddLogLevel,
            flag: level.flag,
            context: 0,
            file: file,
            function: function,
            line: UInt(line),
            tag: nil,
            timestamp: timestamp
        )

        DDLog.log(asynchronous: true, message: logMessage)
    }

    private func fileName(from path: String) -> String {
        (path as NSString).lastPathComponent
    }
}
