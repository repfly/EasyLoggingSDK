import CocoaLumberjack
import Logging
import Foundation
import UIKit
import ObjectiveC

public final class EasyLogger {

    // MARK: - Singleton
    
    public static let shared = EasyLogger()
    
    // MARK: - Properties
    
    private let queue = DispatchQueue(label: "com.easylogging.sdk", qos: .utility)
    private let crashFlagKey = "com.easylogging.sdk.crashFlag"
    private var configuration: Configuration
    private var fileLogger: DDFileLogger?
    private var shakeGestureWindow: UIWindow?
    private let screenTimeTracker = ScreenTimeTracker()
    
    // MARK: - Initialization
    
    private init() {
        self.configuration = Configuration()
        initializeLogger()
    }
    
    // MARK: - Configuration
    
    /// Configuration options for EasyLogger
    public struct Configuration {
        /// Minimum log level to be logged
        public var minimumLogLevel: LogLevel = .debug
        /// Whether to log to console
        public var shouldLogToConsole: Bool = true
        /// Whether to log to file
        public var shouldLogToFile: Bool = true
        /// Whether to detect crashes
        public var shouldDetectCrashes: Bool = true
        /// Whether to enable shake to share logs
        public var enableShakeToShare: Bool = false
        /// Whether to track screen loading times
        public var trackScreenLoadingTimes: Bool = false
        /// Threshold in seconds for slow screen loading warning
        public var slowScreenLoadingThreshold: TimeInterval = 1.0
        /// Custom title for the share dialog
        public var shareDialogTitle: String = "Share Logs"
        /// Custom message for the share dialog
        public var shareDialogMessage: String = "Would you like to share the log files?"
        /// Maximum log file size in bytes (default: 5MB)
        public var maxFileSize: UInt64 = 5_000_000
        /// Maximum number of log files to keep
        public var maxLogFiles: UInt = 7
        /// Log format template
        public var logFormat: LogFormat = .default
        /// Directory where log files are stored
        public var logsDirectory: String?
        /// Whether to use automatic screen time tracking via method swizzling
        public var useAutomaticScreenTimeTracking: Bool = true
        
        public init() {}
    }
    
    /// Configures the logger with the provided options
    public func configure(_ configuration: Configuration) {
        queue.sync {
            let wasTrackingEnabled = self.configuration.trackScreenLoadingTimes && self.configuration.useAutomaticScreenTimeTracking
            let willBeTrackingEnabled = configuration.trackScreenLoadingTimes && configuration.useAutomaticScreenTimeTracking
            
            self.configuration = configuration
            resetLoggers()
            initializeLogger()
            
            // Handle swizzling setup/teardown
            if !wasTrackingEnabled && willBeTrackingEnabled {
                UIViewController.setupScreenTimeTracking()
            } else if wasTrackingEnabled && !willBeTrackingEnabled {
                UIViewController.tearDownScreenTimeTracking()
            }
        }
    }
    
    // MARK: - Initialization
    
    private func initializeLogger() {
        setupConsoleLogging()
        setupFileLogging()
        setupCrashDetection()
        
        LoggingSystem.bootstrap { label in
            LumberjackLogHandler(label: label, minimumLogLevel: self.configuration.minimumLogLevel)
        }
    }
    
    private func setupConsoleLogging() {
        guard configuration.shouldLogToConsole else { return }
        
        DDLog.add(DDOSLogger.sharedInstance)
        if let ttyLogger = DDTTYLogger.sharedInstance {
            DDLog.add(ttyLogger)
        }
    }
    
    private func setupFileLogging() {
        guard configuration.shouldLogToFile else { return }
        
        let logsDirectory = configuration.logsDirectory ?? DirectoryHelper.getLogDirectory()
        let fileManager = DDLogFileManagerDefault(logsDirectory: logsDirectory)
        
        fileLogger = DDFileLogger(logFileManager: fileManager)
        fileLogger?.logFileManager.maximumNumberOfLogFiles = configuration.maxLogFiles
        fileLogger?.maximumFileSize = configuration.maxFileSize
        
        if let fileLogger = fileLogger {
            DDLog.add(fileLogger)
        }
    }
    
    private func resetLoggers() {
        DDLog.removeAllLoggers()
        fileLogger = nil
    }
    
    // MARK: - Crash Detection
    
    private func setupCrashDetection() {
        guard configuration.shouldDetectCrashes else { return }
        
        setUncaughtExceptionHandler()
        detectPreviousCrash()
    }
    
    private func setUncaughtExceptionHandler() {
        NSSetUncaughtExceptionHandler { exception in
            EasyLogger.handleException(exception)
        }
    }
    
    private static func handleException(_ exception: NSException) {
        let logger = EasyLogger.shared
        
        let stack = exception.callStackSymbols.joined(separator: "\n")
        let name = exception.name.rawValue
        let reason = exception.reason ?? "No reason provided"
        
        let crashReport = """
            🚨 CRASH DETECTED 🚨
            Exception: \(name)
            Reason: \(reason)
            Stack Trace:
            \(stack)
            """
        
        logger.log(crashReport, level: .error)
        UserDefaults.standard.set(true, forKey: logger.crashFlagKey)
        UserDefaults.standard.synchronize()
    }
    
    private func detectPreviousCrash() {
        if UserDefaults.standard.bool(forKey: crashFlagKey) {
            log("⚠️ App crashed in the previous session", level: .error)
            UserDefaults.standard.set(false, forKey: crashFlagKey)
            UserDefaults.standard.synchronize()
        }
    }
    
    // MARK: - Logging
    
    /// Logs a message with the specified level and metadata
    public func log(
        _ message: @autoclosure () -> String,
        level: LogLevel = .info,
        metadata: [String: String]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard level.rawValue >= configuration.minimumLogLevel.rawValue else { return }
        
        // Evaluate the message before the async block
        let messageString = message()
        
        queue.async {
            let formattedMessage = self.configuration.logFormat.format(
                message: messageString,
                level: level,
                metadata: metadata,
                file: file,
                function: function,
                line: line
            )
            
            // Using withVaList to properly handle the variadic arguments
            withVaList([formattedMessage as NSString]) { args in
                DDLog.log(
                    asynchronous: true,
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
    }
    
    // MARK: - Convenience Methods
    
    public func debug(
        _ message: @autoclosure () -> String,
        metadata: [String: String]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(
            message(),
            level: .debug,
            metadata: metadata,
            file: file,
            function: function,
            line: line
        )
    }
    
    public func info(
        _ message: @autoclosure () -> String,
        metadata: [String: String]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(
            message(),
            level: .info,
            metadata: metadata,
            file: file,
            function: function,
            line: line
        )
    }
    
    public func warning(
        _ message: @autoclosure () -> String,
        metadata: [String: String]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(
            message(),
            level: .warning,
            metadata: metadata,
            file: file,
            function: function,
            line: line
        )
    }
    
    public func error(
        _ message: @autoclosure () -> String,
        metadata: [String: String]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(
            message(),
            level: .error,
            metadata: metadata,
            file: file,
            function: function,
            line: line
        )
    }
    
    // MARK: - File Management
    
    /// Returns the URL of the current log file
    public var currentLogFileURL: URL? {
        if let filePath = fileLogger?.currentLogFileInfo?.filePath {
            return URL(fileURLWithPath: filePath)
        }
        return nil
    }
    
    /// Rotates the current log file
    /// - Parameter completion: Optional closure to be called when rotation is complete
    public func rotateLogFile(completion: (() -> Void)? = nil) {
        queue.async {
            self.fileLogger?.rollLogFile { [weak self] in
                guard let self = self else { return }
                
                // Log the rotation for debugging purposes
                self.debug("Log file rotated successfully")
                
                // Call the completion handler if provided
                completion?()
            }
        }
    }
    
    /// Removes all log files
    public func removeAllLogFiles() {
        queue.async {
            guard let logFileManager = self.fileLogger?.logFileManager else { return }
            
            // Get the directory containing log files
            let logsDirectory = logFileManager.logsDirectory
            
            do {
                // Get all files in the logs directory
                let fileURLs = try FileManager.default.contentsOfDirectory(
                    at: URL(fileURLWithPath: logsDirectory),
                    includingPropertiesForKeys: nil
                )
                
                // Remove each log file
                for fileURL in fileURLs {
                    try? FileManager.default.removeItem(at: fileURL)
                }
                
                // Force the logger to create a new log file
                self.fileLogger?.rollLogFile(withCompletion: nil)
                
                // Log the cleanup
                self.debug("All log files have been removed")
            } catch {
                self.error("Failed to remove log files: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Lifecycle
    
    /// Call this method when the application will terminate
    public func applicationWillTerminate() {
        queue.sync {
            UserDefaults.standard.set(false, forKey: crashFlagKey)
            UserDefaults.standard.synchronize()
        }
    }
    
    // MARK: - Shake to Share
    
    /// Sets up shake gesture detection for sharing logs
    private func setupShakeToShare() {
        guard configuration.enableShakeToShare else {
            shakeGestureWindow?.isHidden = true
            shakeGestureWindow = nil
            return
        }
        
        if shakeGestureWindow == nil {
            let window = ShakeDetectingWindow(frame: UIScreen.main.bounds)
            window.backgroundColor = .clear
            window.isUserInteractionEnabled = false
            window.windowLevel = .alert
            window.isHidden = false
            window.rootViewController = ShakeDetectingViewController { [weak self] in
                self?.handleShakeGesture()
            }
            self.shakeGestureWindow = window
        }
    }
    
    private func handleShakeGesture() {
        guard let topViewController = UIApplication.shared.keyWindow?.rootViewController?.topMostViewController else {
            return
        }
        
        let alert = UIAlertController(
            title: configuration.shareDialogTitle,
            message: configuration.shareDialogMessage,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Share", style: .default) { [weak self] _ in
            self?.shareLogFiles(from: topViewController)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        topViewController.present(alert, animated: true)
    }
    
    private func shareLogFiles(from viewController: UIViewController) {
        guard let logDirectory = fileLogger?.logFileManager.logsDirectory else { return }
        
        let fileManager = FileManager.default
        let logDirectoryURL = URL(fileURLWithPath: logDirectory)
        
        guard let logFiles = try? fileManager.contentsOfDirectory(
            at: logDirectoryURL,
            includingPropertiesForKeys: nil
        ) else { return }
        
        let activityVC = UIActivityViewController(
            activityItems: logFiles,
            applicationActivities: nil
        )
        
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(x: viewController.view.bounds.midX,
                                      y: viewController.view.bounds.midY,
                                      width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        viewController.present(activityVC, animated: true)
    }
    
    /// Call this method when the application finishes launching
    public func applicationDidFinishLaunching() {
        queue.async {
            self.setupShakeToShare()
        }
    }
    
    // MARK: - Screen Time Tracking
    
    /// Start tracking loading time for a screen
    /// - Parameter viewController: The view controller to track
    public func trackScreenAppearance(_ viewController: UIViewController) {
        guard configuration.trackScreenLoadingTimes else { return }
        screenTimeTracker.trackScreenAppearance(viewController)
    }
    
    /// End tracking loading time for a screen and log the duration
    /// - Parameter viewController: The view controller to stop tracking
    public func endScreenTracking(_ viewController: UIViewController) {
        guard configuration.trackScreenLoadingTimes,
              let duration = screenTimeTracker.endScreenTracking(viewController) else { return }
        
        let screenName = String(describing: type(of: viewController))
        let metadata = [
            "screen": screenName,
            "duration": String(format: "%.3f", duration),
            "tracking_method": configuration.useAutomaticScreenTimeTracking ? "automatic" : "manual"
        ]
        
        if duration >= configuration.slowScreenLoadingThreshold {
            warning("Slow screen loading detected", metadata: metadata)
        } else {
            debug("Screen loaded", metadata: metadata)
        }
    }
    
    /// Clear all screen time tracking data
    public func clearScreenTimeTracking() {
        screenTimeTracker.clearTracking()
    }
}

// MARK: - Convenience Extensions

extension EasyLogger {
    /// Returns whether a specific log level is enabled
    public func isEnabled(level: LogLevel) -> Bool {
        level.rawValue >= configuration.minimumLogLevel.rawValue
    }
}

// MARK: - Helper Classes

private final class ShakeDetectingWindow: UIWindow {
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        guard motion == .motionShake else { return }
        (rootViewController as? ShakeDetectingViewController)?.handleShake()
    }
}

private final class ShakeDetectingViewController: UIViewController {
    private let shakeHandler: () -> Void
    
    init(shakeHandler: @escaping () -> Void) {
        self.shakeHandler = shakeHandler
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func handleShake() {
        shakeHandler()
    }
}

// MARK: - UIViewController Extension

private extension UIViewController {
    var topMostViewController: UIViewController {
        if let presented = presentedViewController {
            return presented.topMostViewController
        }
        if let navigation = self as? UINavigationController {
            return navigation.visibleViewController?.topMostViewController ?? navigation
        }
        if let tab = self as? UITabBarController {
            return tab.selectedViewController?.topMostViewController ?? tab
        }
        return self
    }
}
