import CocoaLumberjack
import Foundation

// MARK: - Crash Detection

extension EasyLogger {
    static func handleException(_ exception: NSException) {
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
            category: "crash",
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

        UserDefaults.standard.set(true, forKey: EasyLogger.shared.crashFlagKey)
    }

    func detectPreviousCrash() {
        guard UserDefaults.standard.bool(forKey: crashFlagKey) == true else { return }
        log(LoggingConstants.CrashDetectionMessage.previousCrash, level: .error)
        UserDefaults.standard.set(false, forKey: crashFlagKey)
    }
}
