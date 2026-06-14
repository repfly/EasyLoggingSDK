import Foundation
import Logging
#if canImport(UIKit)
import UIKit
#endif

/// `@unchecked Sendable` is the textbook-correct annotation here for an iOS 15 / macOS 12 target
/// (no `Mutex`/`OSAllocatedUnfairLock` available): the type's mutable state is hand-synchronized.
///
/// - `_configuration` and `_currentEnvironment` are guarded exclusively by `_lock` (an
///   `os_unfair_lock` wrapper); every read/write goes through the `_lock.withLock { ... }`
///   accessors below.
/// - `_logViewer`, `lifecycleManager`, and `shakeToShareHandler` are only ever touched on the
///   main actor (`logViewer` is `@MainActor`; the UIKit handlers are created and used inside
///   `@MainActor` tasks).
/// - All log delivery is funneled through the `Sendable` `SerialLogPipeline`, which is itself
///   immutable (`let`) after init.
public final class EasyLogger: @unchecked Sendable {
    // MARK: - Singleton

    public static let shared = EasyLogger()

    // MARK: - Properties

    let loggingActor = LoggingActor()

    /// Serializes all logging work (records, configuration applies, flush markers) in FIFO order.
    let pipeline: SerialLogPipeline

    let environmentKey = LoggingConstants.UserDefaultsKey.environment
    var _configuration: Configuration
    let _lock = UnfairLock()
    var _currentEnvironment: LogEnvironment
    let screenTimeTracker = ScreenTimeTracker()

    #if canImport(UIKit)
    var _logViewer: InAppLogViewer!

    // UIKit-only handlers. These are `@MainActor` classes (implicitly `Sendable`) and are only ever
    // created and touched inside `@MainActor` tasks, so storing them on this `@unchecked Sendable`
    // singleton is safe.
    var lifecycleManager: LifecycleManager?
    var shakeToShareHandler: ShakeToShareHandler?
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

    /// The current configuration. Get-only; apply changes via ``configure(_:)`` or
    /// ``setEnvironment(_:configuration:)``. Reads are lock-guarded.
    public var configuration: Configuration {
        _lock.withLock { self._configuration }
    }

    /// The active environment. Get-only; change it via ``setEnvironment(_:configuration:)`` so
    /// persistence, configuration apply, and UIKit reconfiguration always happen together.
    public var environment: LogEnvironment {
        _lock.withLock { self._currentEnvironment }
    }

    // MARK: - Initialization

    private init() {
        let savedEnvironment = UserDefaults.standard.string(forKey: environmentKey)
        let environment = LogEnvironment(rawValue: savedEnvironment ?? "") ?? .development
        let initialConfiguration = environment.defaultConfiguration
        self._currentEnvironment = environment
        self._configuration = initialConfiguration

        // The pipeline routes every event to the actor in strict FIFO order. It is created
        // first so that any early logs/config applies are ordered behind the initial setup.
        let actor = loggingActor
        self.pipeline = SerialLogPipeline { event in
            switch event {
            case let .record(record):
                await actor.process(record)
            case let .applyConfiguration(configuration):
                await actor.applyConfiguration(configuration)
            case let .actorOperation(operation):
                await operation(actor)
            case .flush:
                // Resumed by the pipeline's consumer loop itself; never forwarded here.
                break
            }
        }

        #if canImport(UIKit)
        self._logViewer = InAppLogViewer(logger: self)
        // Wire the in-app viewer onto the actor as the *first* pipeline event so it is observed
        // before any log record is processed; otherwise early records enqueued before a separate
        // setup `Task` lands would be dropped from the in-memory viewer buffer (Phase 7 race fix).
        if let viewer = _logViewer {
            pipeline.enqueue(.actorOperation { actor in
                await actor.setLogViewer(viewer)
            })
        }
        #endif

        // Initial configuration is enqueued through the pipeline so it is ordered ahead of any
        // early logs.
        pipeline.enqueue(.applyConfiguration(initialConfiguration))

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

    public func setEnvironment(_ environment: LogEnvironment, configuration: Configuration? = nil) {
        _lock.withLock { self._currentEnvironment = environment }
        UserDefaults.standard.set(environment.rawValue, forKey: self.environmentKey)
        applyConfigurationChange(configuration ?? environment.defaultConfiguration)
    }

    /// The single chokepoint for applying a configuration: swaps the lock-guarded configuration,
    /// orders the apply through the pipeline (preserving FIFO with logs), and reconfigures the
    /// UIKit integrations. Both the sync and async `configure`/`setEnvironment` entry points route
    /// through here so their side effects can never drift apart.
    func applyConfigurationChange(_ new: Configuration) {
        let previous = _lock.withLock { () -> Configuration in
            let old = self._configuration
            self._configuration = new
            return old
        }
        pipeline.enqueue(.applyConfiguration(new))
        #if canImport(UIKit)
        applyUIKitConfiguration(previous: previous, new: new)
        #endif
    }

    /// Configuration for the logging SDK.
    ///
    /// Use environment presets for quick setup:
    /// ```swift
    /// EasyLogger.shared.setEnvironment(.production)
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

        /// Write logs to rotating files on disk. Required for log sharing (the in-app viewer shows
        /// the in-memory, since-launch buffer regardless of this flag).
        public var shouldLogToFile: Bool = true

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

        /// Enable the in-app log viewer overlay accessible via gesture. Requires ``shouldLogToFile`` for file history.
        public var enableInAppLogViewer: Bool = false

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
        applyConfigurationChange(configuration)
    }

    #if canImport(UIKit)
    private func applyUIKitConfiguration(previous: Configuration, new: Configuration) {
        let wasTrackingEnabled = previous.trackScreenLoadingTimes && previous.useAutomaticUIKitScreenTimeTracking
        let willBeTrackingEnabled = new.trackScreenLoadingTimes && new.useAutomaticUIKitScreenTimeTracking
        if !wasTrackingEnabled, willBeTrackingEnabled {
            Task { @MainActor in UIViewController.setupScreenTimeTracking() }
        } else if wasTrackingEnabled, !willBeTrackingEnabled {
            Task { @MainActor in UIViewController.tearDownScreenTimeTracking() }
        }

        let logViewerConfigChanged = previous.enableInAppLogViewer != new.enableInAppLogViewer
            || previous.logViewerActivationGesture != new.logViewerActivationGesture
            || previous.maxLogViewerEntries != new.maxLogViewerEntries

        if logViewerConfigChanged || new.enableInAppLogViewer {
            Task { @MainActor in
                self.logViewer.configure(
                    isEnabled: new.enableInAppLogViewer,
                    activationGesture: new.logViewerActivationGesture,
                    maxLogEntries: new.maxLogViewerEntries
                )
            }
        }

        let shakeConfigChanged = previous.enableShakeToShare != new.enableShakeToShare
            || previous.shareDialogTitle != new.shareDialogTitle
            || previous.shareDialogMessage != new.shareDialogMessage

        if shakeConfigChanged || new.enableShakeToShare {
            Task { @MainActor in
                self.shakeToShareHandler?.setupShakeToShare()
            }
        }
    }
    #endif

    // MARK: - Logging

    /// Logs a message with the specified level and optional metadata.
    ///
    /// Redaction is applied here — before any value crosses the actor boundary — so every
    /// public logging path is guaranteed to redact. Configuration and environment are read
    /// outside the logging actor to avoid deadlock if configuration changes trigger logging
    /// while a log is in flight.
    ///
    /// - Important: Redaction protects *metadata* values, not the `message` string. The message
    ///   is logged verbatim, so do not interpolate secrets into it — pass sensitive values as
    ///   metadata (sensitive-looking keys are redacted automatically; use
    ///   ``LogMetadata/setRedactable(_:forKey:redaction:)`` for explicit control).
    public func log(_ message: @autoclosure () -> String, level: LogLevel = .info, category: String? = nil, metadata: LogMetadata? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        let config = self.configuration
        guard level >= config.minimumLogLevel else { return }

        let messageString = message()
        let isProduction = self.environment == .production
        // Redaction happens HERE, before the value crosses the pipeline/actor boundary. The
        // `[String: String]` carried by `LogRecord` is therefore already redacted, so everything
        // downstream — the in-app viewer's in-memory buffer (via `addLogEntry`) and the formatted
        // on-disk files exported by `shareLogFiles` — only ever sees redacted metadata.
        let redacted: [String: String]? = metadata?.redactedDictionary(isProduction: isProduction)
        let record = LogRecord(
            messageString: messageString,
            level: level,
            category: category,
            metadata: redacted,
            file: file,
            function: function,
            line: line,
            config: config,
            isInternal: false
        )
        pipeline.enqueue(.record(record))
    }

    /// Awaits until all previously enqueued log records and configuration applies have been
    /// fully processed and delivered. Use this to guarantee logs are flushed (e.g. before exit).
    public func flush() async {
        await pipeline.flush()
    }

    func applicationDidFinishLaunching() {
        #if canImport(UIKit)
        Task { @MainActor in
            self.shakeToShareHandler?.setupShakeToShare()
        }
        #endif
    }
}
