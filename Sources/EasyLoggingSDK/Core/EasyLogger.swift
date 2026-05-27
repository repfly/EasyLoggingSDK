import CocoaLumberjack
import Foundation
import Logging

public final class EasyLogger: @unchecked Sendable {
    // MARK: - Singleton

    public static let shared = EasyLogger()

    // MARK: - Properties

    let loggingActor = LoggingActor()

    let crashFlagKey = LoggingConstants.UserDefaultsKey.crashFlag
    let environmentKey = LoggingConstants.UserDefaultsKey.environment
    var _configuration: Configuration
    let _lock = UnfairLock()
    var _currentEnvironment: LogEnvironment
    let screenTimeTracker = ScreenTimeTracker()

    #if canImport(UIKit)
    var memoryLeakDetector: MemoryLeakDetector!
    var _logViewer: InAppLogViewer!

    /// Internal access to the file logger for ``InAppLogViewer`` file history.
    ///
    /// This bridges to ``LoggingActor`` synchronously and is intended for UI-triggered reads.
    var internalFileLogger: DDFileLogger? {
        var result: DDFileLogger?
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            result = await loggingActor.fileLogger
            semaphore.signal()
        }
        semaphore.wait()
        return result
    }

    // UIKit-related handlers (typed as `Any` to keep the core target free of UIKit at the type level).
    var lifecycleManager: Any?
    var shakeToShareHandler: Any?
    #endif

    #if canImport(UIKit)
    @MainActor
    var logViewer: InAppLogViewer {
        return _logViewer
    }
    #endif

    /// Returns whether shake-to-share is currently enabled.
    var isShakeToShareEnabled: Bool {
        _lock.withLock { self._configuration.enableShakeToShare }
    }

    // Thread-safe configuration access using unfair lock.
    public var configuration: Configuration {
        get { _lock.withLock { self._configuration } }
        set {
            let previous = _lock.withLock {
                let old = self._configuration
                self._configuration = newValue
                return old
            }
            Task { await self.loggingActor.applyConfiguration(newValue) }
            #if canImport(UIKit)
            applyUIKitConfiguration(previous: previous, new: newValue)
            #endif
        }
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
        self.memoryLeakDetector = MemoryLeakDetector(logger: self)
        #endif

        Task { [config = self._configuration] in
            #if canImport(UIKit)
            await self.loggingActor.setLogViewer(self._logViewer)
            #endif
            await self.loggingActor.applyConfiguration(config)
            await self.loggingActor.setupCrashDetection(with: config)
            self.detectPreviousCrash()
        }

        setupUIKitIntegrationsIfAvailable()
    }

    deinit {}

    private func setupUIKitIntegrationsIfAvailable() {
        #if canImport(UIKit)
        Task { @MainActor in
            self.lifecycleManager = LifecycleManager(logger: self)
            self.shakeToShareHandler = ShakeToShareHandler(logger: self)
        }
        #endif
    }

    // MARK: - Configuration

    public func setupEnvironment(_ environment: LogEnvironment, customConfiguration: Configuration? = nil) {
        let previous = _lock.withLock {
            self._currentEnvironment = environment
            return self._configuration
        }
        UserDefaults.standard.set(environment.rawValue, forKey: self.environmentKey)

        let config = customConfiguration ?? environment.defaultConfiguration
        _lock.withLock { self._configuration = config }

        Task {
            await self.loggingActor.applyConfiguration(config)
        }

        #if canImport(UIKit)
        applyUIKitConfiguration(previous: previous, new: config)
        #endif
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

    /// Applies a new configuration and reinitializes loggers and optional UIKit integrations.
    public func configure(_ configuration: Configuration) {
        let previous = self.configuration
        _lock.withLock { self._configuration = configuration }
        Task {
            await self.loggingActor.applyConfiguration(configuration)
        }
        #if canImport(UIKit)
        applyUIKitConfiguration(previous: previous, new: configuration)
        #endif
    }

    #if canImport(UIKit)
    private func applyUIKitConfiguration(previous: Configuration, new: Configuration) {
        let wasTrackingEnabled = previous.trackScreenLoadingTimes && previous.useAutomaticUIKitScreenTimeTracking
        let willBeTrackingEnabled = new.trackScreenLoadingTimes && new.useAutomaticUIKitScreenTimeTracking
        if !wasTrackingEnabled, willBeTrackingEnabled {
            UIViewController.setupScreenTimeTracking()
        } else if wasTrackingEnabled, !willBeTrackingEnabled {
            UIViewController.tearDownScreenTimeTracking()
        }

        let wasLeakDetectionEnabled = previous.enableMemoryLeakDetection
        let willBeLeakDetectionEnabled = new.enableMemoryLeakDetection
        if !wasLeakDetectionEnabled, willBeLeakDetectionEnabled {
            memoryLeakDetector = MemoryLeakDetector(logger: self, checkInterval: new.memoryLeakCheckInterval)
            Task { await memoryLeakDetector.startMonitoring() }
        } else if wasLeakDetectionEnabled, !willBeLeakDetectionEnabled {
            Task { await memoryLeakDetector.stopMonitoring() }
        } else if wasLeakDetectionEnabled, willBeLeakDetectionEnabled {
            Task {
                await memoryLeakDetector.stopMonitoring()
                self.memoryLeakDetector = MemoryLeakDetector(logger: self, checkInterval: new.memoryLeakCheckInterval)
                await self.memoryLeakDetector.startMonitoring()
            }
        }

        let logViewerConfigChanged = previous.enableInAppLogViewer != new.enableInAppLogViewer
            || previous.logViewerActivationGesture != new.logViewerActivationGesture
            || previous.logViewerAccessCode != new.logViewerAccessCode
            || previous.maxLogViewerEntries != new.maxLogViewerEntries

        if logViewerConfigChanged || new.enableInAppLogViewer {
            Task { @MainActor in
                self.logViewer.configure(
                    isEnabled: new.enableInAppLogViewer,
                    activationGesture: new.logViewerActivationGesture,
                    accessCode: new.logViewerAccessCode,
                    maxLogEntries: new.maxLogViewerEntries
                )
            }
        }

        let shakeConfigChanged = previous.enableShakeToShare != new.enableShakeToShare
            || previous.shareDialogTitle != new.shareDialogTitle
            || previous.shareDialogMessage != new.shareDialogMessage

        if shakeConfigChanged || new.enableShakeToShare {
            Task { @MainActor in
                (self.shakeToShareHandler as? ShakeToShareHandler)?.setupShakeToShare()
            }
        }
    }
    #endif

    // MARK: - Logging

    /// Logs a message with the specified level and optional metadata.
    ///
    /// Configuration is read outside the logging actor to avoid deadlock if configuration
    /// changes trigger logging while a log is in flight.
    public func log(_ message: @autoclosure () -> String, level: LogLevel = .info, category: String? = nil, metadata: [String: Any]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        let config = self.configuration
        guard level >= config.minimumLogLevel else { return }

        let messageString = message()
        Task {
            await self.loggingActor.log(
                messageString: messageString,
                level: level,
                category: category,
                metadata: metadata,
                file: file,
                function: function,
                line: line,
                config: config
            )
        }
    }

    public func log<T: Codable>(_ message: @autoclosure () -> String, level: LogLevel = .info, category: String? = nil, metadata: T, file: String = #file, function: String = #function, line: Int = #line) {
        let encodedMetadata = encodeCodableToMetadata(metadata)
        log(message(), level: level, category: category, metadata: encodedMetadata, file: file, function: function, line: line)
    }

    public func log<T: Codable>(_ message: @autoclosure () -> String, level: LogLevel = .info, category: String? = nil, metadata: [String: Any]?, codableMetadata: T, file: String = #file, function: String = #function, line: Int = #line) {
        var combinedMetadata = metadata ?? [:]
        let encodedCodable = encodeCodableToMetadata(codableMetadata)

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
                return ["codable_data": jsonString]
            }
        } catch {
            return ["codable_error": "Failed to encode: \(error.localizedDescription)", "codable_description": String(describing: codable)]
        }

        return ["codable_fallback": String(describing: codable)]
    }

    func applicationWillTerminate() {
        Task {
            await loggingActor.applicationWillTerminate(crashFlagKey: self.crashFlagKey)
        }
    }

    func applicationDidFinishLaunching() {
        #if canImport(UIKit)
        Task { @MainActor in
            (self.shakeToShareHandler as? ShakeToShareHandler)?.setupShakeToShare()
        }
        #endif
    }
}
