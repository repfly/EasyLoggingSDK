import Foundation
import Logging

/// `@unchecked Sendable` is the textbook-correct annotation here for an iOS 15 / macOS 12 target
/// (no `Mutex`/`OSAllocatedUnfairLock` available): the type's mutable state is hand-synchronized.
///
/// - `configurationStorage`, `currentEnvironmentStorage`, and `integrations` are guarded exclusively
///   by `stateLock` (an `os_unfair_lock` wrapper); every read/write goes through the
///   `stateLock.withLock { ... }` accessors below.
/// - All log delivery is funneled through the `Sendable` `SerialLogPipeline`, which is itself
///   immutable (`let`) after init.
/// - UIKit/SwiftUI features live in separate targets and attach via ``register(_:)`` /
///   ``registerLogSink(_:)``; this type holds no reference to any UIKit type.
public final class EasyLogger: @unchecked Sendable {
    // MARK: - Singleton

    public static let shared = EasyLogger()

    // MARK: - Properties

    let loggingActor = LoggingActor()

    /// Serializes all logging work (records, configuration applies, flush markers) in FIFO order.
    let pipeline: SerialLogPipeline

    let environmentKey = LoggingConstants.UserDefaultsKey.environment
    var configurationStorage: Configuration
    let stateLock = UnfairLock()
    var currentEnvironmentStorage: LogEnvironment

    /// Registered feature integrations (viewer, screen tracking, shake-to-share, …), guarded by
    /// `stateLock`. Populated by feature targets via ``register(_:)``.
    private var integrations: [any EasyLoggerIntegration] = []

    /// The current configuration. Get-only; apply changes via ``configure(_:)`` or
    /// ``setEnvironment(_:configuration:)``. Reads are lock-guarded.
    public var configuration: Configuration {
        stateLock.withLock { self.configurationStorage }
    }

    /// The active environment. Get-only; change it via ``setEnvironment(_:configuration:)`` so
    /// persistence, configuration apply, and UIKit reconfiguration always happen together.
    public var environment: LogEnvironment {
        stateLock.withLock { self.currentEnvironmentStorage }
    }

    // MARK: - Initialization

    private init() {
        let savedEnvironment = UserDefaults.standard.string(forKey: environmentKey)
        let environment = LogEnvironment(rawValue: savedEnvironment ?? "") ?? .development
        let initialConfiguration = environment.defaultConfiguration
        self.currentEnvironmentStorage = environment
        self.configurationStorage = initialConfiguration

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

        // Initial configuration is enqueued through the pipeline so it is ordered ahead of any
        // early logs.
        pipeline.enqueue(.applyConfiguration(initialConfiguration))
    }

    deinit {}

    // MARK: - Integrations

    /// Registers a feature integration. The current configuration is replayed immediately (so a
    /// late registrant catches up), then every subsequent change is forwarded. Registering the
    /// same instance again is a no-op, which keeps `install()`-style entry points idempotent.
    ///
    /// The replay runs outside `stateLock` (calling out under the lock could deadlock if an
    /// integration re-enters the logger), so a `configure` racing a `register` can deliver the
    /// newer configuration before the `previous: nil` replay. Register integrations at launch,
    /// before configuration churn, to avoid acting on the stale replay.
    public func register(_ integration: any EasyLoggerIntegration) {
        let replay = stateLock.withLock { () -> Configuration? in
            guard !self.integrations.contains(where: { $0 === integration }) else { return nil }
            self.integrations.append(integration)
            return self.configurationStorage
        }
        guard let replay else { return }
        integration.apply(previous: nil, new: replay)
    }

    /// Routes log records to a ``LogSink``, enqueued through the pipeline to preserve FIFO order.
    public func registerLogSink(_ sink: any LogSink) {
        pipeline.enqueue(.actorOperation { actor in
            await actor.setLogSink(sink)
        })
    }

    private func notifyIntegrations(previous: Configuration, new: Configuration) {
        let current = stateLock.withLock { self.integrations }
        for integration in current {
            integration.apply(previous: previous, new: new)
        }
    }

    // MARK: - Configuration

    public func setEnvironment(_ environment: LogEnvironment, configuration: Configuration? = nil) {
        stateLock.withLock { self.currentEnvironmentStorage = environment }
        UserDefaults.standard.set(environment.rawValue, forKey: self.environmentKey)
        applyConfigurationChange(configuration ?? environment.defaultConfiguration)
    }

    /// The single chokepoint for applying a configuration: swaps the lock-guarded configuration,
    /// orders the apply through the pipeline (preserving FIFO with logs), and notifies registered
    /// integrations. Both the sync and async `configure`/`setEnvironment` entry points route
    /// through here so their side effects can never drift apart.
    func applyConfigurationChange(_ new: Configuration) {
        let previous = stateLock.withLock { () -> Configuration in
            let old = self.configurationStorage
            self.configurationStorage = new
            return old
        }
        pipeline.enqueue(.applyConfiguration(new))
        notifyIntegrations(previous: previous, new: new)
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
        /// When `true`, ``networkLoggingSessionConfiguration(base:)`` is available to create
        /// a pre-configured `URLSessionConfiguration`.
        public var enableNetworkLogging: Bool = false

        /// Maximum number of network requests retained by the in-app network inspector. Default: 500.
        public var maxNetworkViewerEntries: Int = LoggingConstants.Defaults.maxNetworkViewerEntries

        public init() {}
    }

    /// Applies a new configuration, reinitializes loggers, and notifies registered integrations.
    public func configure(_ configuration: Configuration) {
        applyConfigurationChange(configuration)
    }

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
    public func log(
        _ message: @autoclosure () -> String,
        level: LogLevel = .info,
        category: String? = nil,
        metadata: LogMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
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
}
