import CocoaLumberjack
import Foundation
import Logging

public final class EasyLogger: @unchecked Sendable {
    // MARK: - Singleton
    
    public static let shared = EasyLogger()

    // MARK: - Properties
    
    let queue = DispatchQueue(label: "com.easylogger.sdk.queue")
    
    let crashFlagKey = LoggingConstants.UserDefaultsKey.crashFlag
    let environmentKey = LoggingConstants.UserDefaultsKey.environment
    var _configuration: Configuration
    let _lock = UnfairLock()
    var fileLogger: DDFileLogger?
    var _currentEnvironment: LogEnvironment
    let screenTimeTracker = ScreenTimeTracker()

    #if canImport(UIKit)
    lazy var memoryLeakDetector = MemoryLeakDetector(logger: self)
    var _logViewer: InAppLogViewer!

    // Internal access to fileLogger for InAppLogViewer
    var internalFileLogger: DDFileLogger? {
        return self.fileLogger
    }

    // UIKit-related handlers
    var lifecycleManager: Any?
    var shakeToShareHandler: Any?
    #endif

    static var isLoggingSystemBootstrapped = false
    static let bootstrapLock = NSLock()
    
    #if canImport(UIKit)
    var logViewer: InAppLogViewer {
        return _logViewer
    }
    #endif

    /// Returns whether shake-to-share is currently enabled
    var isShakeToShareEnabled: Bool {
        _lock.withLock { self._configuration.enableShakeToShare }
    }

    // Thread-safe configuration access using unfair lock
    public var configuration: Configuration {
        get { _lock.withLock { self._configuration } }
        set { _lock.withLock { self._configuration = newValue } }
    }

    public var environment: LogEnvironment {
        get { _lock.withLock { self._currentEnvironment } }
        set { _lock.withLock { self._currentEnvironment = newValue } }
    }
    
    // MARK: - Initialization

    private init() {
        let savedEnvironment = UserDefaults.standard.string(forKey: environmentKey)
        self._currentEnvironment = LogEnvironment(rawValue: savedEnvironment ?? "") ?? .development
        self._configuration = self._currentEnvironment.defaultConfiguration

        #if canImport(UIKit)
        self._logViewer = InAppLogViewer(logger: self)
        #endif

        initializeLogger(with: self._configuration)
        setupUIKitIntegrationsIfAvailable()
    }
    
    deinit {}
    
    private func setupUIKitIntegrationsIfAvailable() {
        #if canImport(UIKit)
        self.lifecycleManager = LifecycleManager(logger: self)
        self.shakeToShareHandler = ShakeToShareHandler(logger: self)
        #endif
    }
    
    // MARK: - Configuration
    
    public func setupEnvironment(_ environment: LogEnvironment, customConfiguration: Configuration? = nil) {
        queue.async {
            self._currentEnvironment = environment
            UserDefaults.standard.set(environment.rawValue, forKey: self.environmentKey)
            
            if let customConfig = customConfiguration {
                self.performConfiguration(customConfig)
            } else {
                self.performConfiguration(environment.defaultConfiguration)
            }
        }
    }
    
    /// Configuration for the logging SDK.
    ///
    /// Use environment presets for quick setup:
    /// ```swift
    /// EasyLogger.shared.setupEnvironment(.production)
    /// ```
    /// Or customize individual properties:
    /// ```swift
    /// var config = EasyLogger.Configuration()
    /// config.minimumLogLevel = .warning
    /// config.shouldLogToFile = true
    /// EasyLogger.shared.configure(config)
    /// ```
    public struct Configuration: Sendable {
        /// Minimum severity level for logs to be recorded. Logs below this level are discarded.
        public var minimumLogLevel: LogLevel = .debug

        /// Write logs to the system console via CocoaLumberjack's OS logger.
        public var shouldLogToConsole: Bool = true

        /// Write logs to rotating files on disk. Required for log sharing and the in-app viewer's file history.
        public var shouldLogToFile: Bool = true

        /// Install an uncaught exception handler to log crashes and detect previous-session crashes on next launch.
        public var shouldDetectCrashes: Bool = true

        /// Enable shake-to-share: shaking the device presents a share sheet with log files. UIKit only.
        public var enableShakeToShare: Bool = false

        /// Enable screen loading time measurement. Works with both manual tracking calls and automatic UIKit swizzling.
        public var trackScreenLoadingTimes: Bool = false

        /// Duration (seconds) after which a screen load is logged as a warning. Default: 1.0s.
        public var slowScreenLoadingThreshold: TimeInterval = LoggingConstants.Defaults.slowScreenLoadingThreshold

        /// Title shown in the shake-to-share alert dialog.
        public var shareDialogTitle: String = LoggingConstants.Defaults.shareDialogTitle

        /// Message body shown in the shake-to-share alert dialog.
        public var shareDialogMessage: String = LoggingConstants.Defaults.shareDialogMessage

        /// Maximum size (bytes) of a single log file before rotation. Default: 5 MB.
        public var maxFileSize: UInt64 = LoggingConstants.Defaults.maxFileSize

        /// Maximum number of rotated log files to keep on disk. Default: 7.
        public var maxLogFiles: UInt = LoggingConstants.Defaults.maxLogFiles

        /// Template-based format for log messages. See ``LogFormat`` for presets.
        public var logFormat: LogFormat = .default

        /// Custom directory path for log files. If nil, uses the default caches subdirectory.
        public var logsDirectory: String?

        /// Automatically swizzle UIViewController lifecycle methods to track screen times without manual calls.
        /// Requires ``trackScreenLoadingTimes`` to be `true`.
        public var useAutomaticUIKitScreenTimeTracking: Bool = false

        /// Periodically check monitored objects for potential memory leaks. UIKit only.
        public var enableMemoryLeakDetection: Bool = false

        /// Interval (seconds) between memory leak checks. Default: 5.0s.
        public var memoryLeakCheckInterval: TimeInterval = LoggingConstants.TimeInterval.defaultLeakCheckInterval

        /// Enable the in-app log viewer overlay accessible via gesture. Requires ``shouldLogToFile`` for file history.
        public var enableInAppLogViewer: Bool = false

        /// Optional access code required to open the in-app log viewer. Useful for QA builds.
        public var logViewerAccessCode: String?

        /// Gesture that activates the in-app log viewer.
        public var logViewerActivationGesture: ActivationGesture = .shake

        /// Maximum number of in-memory log entries retained by the log viewer. Default: 1000.
        public var maxLogViewerEntries: Int = 1000

        /// Enable automatic network request logging via ``NetworkLoggerURLProtocol``.
        /// When `true`, ``networkLoggingSessionConfiguration()`` is available to create
        /// a pre-configured `URLSessionConfiguration`.
        public var enableNetworkLogging: Bool = false

        public init() {}
    }

    public func configure(_ configuration: Configuration) {
        queue.async {
            self.performConfiguration(configuration)
        }
    }

    private func performConfiguration(_ configuration: Configuration) {
        let previousConfig = _lock.withLock { self._configuration }
        _lock.withLock { self._configuration = configuration }

        resetLoggers()
        initializeLogger(with: configuration)

        #if canImport(UIKit)
        let wasTrackingEnabled = previousConfig.trackScreenLoadingTimes && previousConfig.useAutomaticUIKitScreenTimeTracking
        let willBeTrackingEnabled = configuration.trackScreenLoadingTimes && configuration.useAutomaticUIKitScreenTimeTracking
        if !wasTrackingEnabled, willBeTrackingEnabled {
            UIViewController.setupScreenTimeTracking()
        } else if wasTrackingEnabled, !willBeTrackingEnabled {
            UIViewController.tearDownScreenTimeTracking()
        }

        let wasLeakDetectionEnabled = previousConfig.enableMemoryLeakDetection
        let willBeLeakDetectionEnabled = configuration.enableMemoryLeakDetection
        if !wasLeakDetectionEnabled, willBeLeakDetectionEnabled {
            memoryLeakDetector = MemoryLeakDetector(logger: self, checkInterval: configuration.memoryLeakCheckInterval)
            memoryLeakDetector.startMonitoring()
        } else if wasLeakDetectionEnabled, !willBeLeakDetectionEnabled {
            memoryLeakDetector.stopMonitoring()
        } else if wasLeakDetectionEnabled, willBeLeakDetectionEnabled {
            memoryLeakDetector.stopMonitoring()
            memoryLeakDetector = MemoryLeakDetector(logger: self, checkInterval: configuration.memoryLeakCheckInterval)
            memoryLeakDetector.startMonitoring()
        }

        let wasLogViewerEnabled = previousConfig.enableInAppLogViewer
        let willBeLogViewerEnabled = configuration.enableInAppLogViewer
        if wasLogViewerEnabled != willBeLogViewerEnabled || willBeLogViewerEnabled {
            DispatchQueue.main.async {
                self.logViewer.configure(
                    isEnabled: configuration.enableInAppLogViewer,
                    activationGesture: configuration.logViewerActivationGesture,
                    accessCode: configuration.logViewerAccessCode,
                    maxLogEntries: configuration.maxLogViewerEntries
                )
            }
        }
        #endif
    }

    public func log(_ message: @autoclosure () -> String, level: LogLevel = .info, category: String? = nil, metadata: [String: Any]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        // Get config outside the queue to avoid deadlock
        let config = self.configuration
        guard level >= config.minimumLogLevel else { return }
        
        let messageString = message()
        queue.async {
            let formattedMessage = config.logFormat.format(message: messageString, level: level, metadata: metadata?.mapValues { String(describing: $0) }, category: category, file: file, function: function, line: line)
            
            #if canImport(UIKit)
            if config.enableInAppLogViewer {
                self.logViewer.addLogEntry(message: messageString, level: level, category: category, metadata: metadata?.mapValues { String(describing: $0) })
            }
            #endif
            
            withVaList([formattedMessage as NSString]) { args in
                DDLog.log(asynchronous: false, level: level.ddLogLevel, flag: level.flag, context: 0, file: file, function: function, line: UInt(line), tag: nil, format: "%@", arguments: args)
            }
        }
    }

    public func log<T: Codable>(_ message: @autoclosure () -> String, level: LogLevel = .info, category: String? = nil, metadata: T, file: String = #file, function: String = #function, line: Int = #line) {
        let encodedMetadata = encodeCodableToMetadata(metadata)
        log(message(), level: level, category: category, metadata: encodedMetadata, file: file, function: function, line: line)
    }

    public func log<T: Codable>(_ message: @autoclosure () -> String, level: LogLevel = .info, category: String? = nil, metadata: [String: Any]?, codableMetadata: T, file: String = #file, function: String = #function, line: Int = #line) {
        var combinedMetadata = metadata ?? [:]
        let encodedCodable = encodeCodableToMetadata(codableMetadata)
        
        // Merge the two metadata dictionaries
        for (key, value) in encodedCodable {
            combinedMetadata[key] = value
        }
        
        log(message(), level: level, category: category, metadata: combinedMetadata, file: file, function: function, line: line)
    }

    func encodeCodableToMetadata<T: Codable>(_ codable: T) -> [String: Any] {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(codable)
            
            if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return jsonObject
            } else if let jsonString = String(data: data, encoding: .utf8) {
                // If it's not a dictionary (e.g., array or primitive), store as JSON string
                return ["codable_data": jsonString]
            }
        } catch {
            // If encoding fails, fall back to description
            return ["codable_error": "Failed to encode: \(error.localizedDescription)", "codable_description": String(describing: codable)]
        }
        
        return ["codable_fallback": String(describing: codable)]
    }
    
    func applicationWillTerminate() {
        queue.async {
            UserDefaults.standard.set(false, forKey: self.crashFlagKey)
        }
    }
    
    func applicationDidFinishLaunching() {
        #if canImport(UIKit)
        DispatchQueue.main.async {
            (self.shakeToShareHandler as? ShakeToShareHandler)?.setupShakeToShare()
        }
        #endif
    }

    func performOnInternalQueue(_ block: @escaping () -> Void) {
        queue.async {
            block()
        }
    }
}
