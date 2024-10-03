import CocoaLumberjack
import Logging
import Foundation

public class EasyLogger {
    public static let shared = EasyLogger()

    var hasCrashed: Bool {
        UserDefaults.standard.bool(forKey: crashFlagKey) ?? false
    }

    private let crashFlagKey = "wasAppCrashed"

    private init() {
        initLogger()
    }

    private func initLogger() {
        DDLog.add(DDOSLogger.sharedInstance)
        if let instance = DDTTYLogger.sharedInstance {
            DDLog.add(instance)
        }
        setUncaughtExceptionHandler()
        debugPrint("Logging session started.")

        LoggingSystem.bootstrap { label in
             LumberjackLogHandler(label: label)
         }
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
            EasyLogger.shared.log(crashReport, level: .error)
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

    public func setup(crashDetection: Bool) {
        if crashDetection {
            detectPreviousCrash()
        }
        configureFileLogger()
    }

    private func configureFileLogger() {
        let logsDirectory = DirectoryHelper.getLogDirectory()
        let fileManager = DDLogFileManagerDefault(logsDirectory: logsDirectory)
        let fileLogger = DDFileLogger(logFileManager: fileManager)
        fileLogger.logFileManager.maximumNumberOfLogFiles = 1
        fileLogger.rollingFrequency = 0
        fileLogger.maximumFileSize = 1_000_000 * 5

        DDLog.add(fileLogger)
    }

    public func log(
        _ message: String,
        level: LogLevel = .info,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
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
            timestamp: .init()
        )

        DDLog.log(asynchronous: true, message: logMessage)
    }

    private func fileName(from path: String) -> String {
        (path as NSString).lastPathComponent
    }
}
