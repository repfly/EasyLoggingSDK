#if canImport(UIKit)
import UIKit

/// A component that provides in-app log viewing capabilities for QA testing.
///
/// Most methods are `@MainActor` since they deal with UI. The `addLogEntry` method
/// is `nonisolated` and uses a lock because it's called from the logging actor.
@MainActor
public final class InAppLogViewer {
    // MARK: - Properties

    private weak var logger: EasyLogger?
    private var isEnabled: Bool = false
    private var activationGesture: ActivationGesture = .shake
    private var logViewerWindow: UIWindow?
    // `nonisolated(unsafe)`: the in-memory log buffer is mutated from the nonisolated
    // `addLogEntry` (called off-main by the logging actor) as well as from the main actor. All
    // access is hand-synchronized through `logEntriesLock`, so it is intentionally not bound to
    // the type's `@MainActor` isolation.
    nonisolated(unsafe) private var maxLogEntries: Int = 1000
    nonisolated(unsafe) private var logEntries: [LogEntry] = []
    private let logEntriesLock = UnfairLock()

    var currentLogger: EasyLogger? {
        return logger
    }

    // MARK: - Types

    /// A single log entry held in the viewer's in-memory, since-launch buffer. Metadata is already
    /// redacted upstream by ``EasyLogger/log(_:level:category:metadata:file:function:line:)``.
    struct LogEntry {
        let timestamp: Date
        let level: LogLevel
        let message: String
        let category: String?
        let metadata: [String: String]?

        var formattedTimestamp: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"
            return formatter.string(from: timestamp)
        }

        var levelColor: UIColor {
            switch level {
            case .trace: return .systemGray2
            case .debug: return .systemGray
            case .info: return .systemBlue
            case .warning: return .systemOrange
            case .error: return .systemRed
            case .critical: return .systemPurple
            }
        }
    }

    public typealias ActivationGesture = EasyLoggingSDK.ActivationGesture

    // MARK: - Initialization

    /// `nonisolated` so the singleton `EasyLogger` (a nonisolated context) can construct the
    /// viewer during its own init. The initializer only stores the back-reference; it touches no
    /// main-actor-isolated state.
    nonisolated init(logger: EasyLogger) {
        self.logger = logger
    }

    // MARK: - Configuration

    func configure(isEnabled: Bool, activationGesture: ActivationGesture, maxLogEntries: Int) {
        self.isEnabled = isEnabled
        self.activationGesture = activationGesture
        // `maxLogEntries` is read under the lock by the nonisolated `addLogEntry`, so write it
        // under the same lock to avoid a data race.
        logEntriesLock.withLock {
            self.maxLogEntries = maxLogEntries
        }

        if isEnabled {
            setupGestureRecognition()
        } else {
            tearDownGestureRecognition()
        }
    }

    // MARK: - Log Management

    /// Add a log entry to the in-memory collection.
    /// This is `nonisolated` because it's called from the LoggingActor (off-main).
    /// Thread safety is provided by `logEntriesLock`.
    nonisolated func addLogEntry(message: String, level: LogLevel, category: String? = nil, metadata: [String: String]? = nil) {
        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            message: message,
            category: category,
            metadata: metadata
        )

        logEntriesLock.withLock {
            self.logEntries.append(entry)
            if self.logEntries.count > self.maxLogEntries {
                self.logEntries.removeFirst(self.logEntries.count - self.maxLogEntries)
            }
        }
    }

    func clearLogs() {
        logEntriesLock.withLock {
            self.logEntries.removeAll()
        }
    }
}

// MARK: - Filtering

extension InAppLogViewer {
    /// Returns the viewer's in-memory log entries (newest first) with optional filtering.
    ///
    /// The in-memory structured buffer is the single source of truth: it contains exactly the
    /// entries captured since launch. Cross-launch history is intentionally not reconstructed by
    /// re-parsing formatted text off disk — file SHARING via ``EasyLogger/shareLogFiles(from:)``
    /// still exports the full on-disk logs. Metadata here is already redacted upstream.
    func getAllLogEntries(searchText: String? = nil, levels: Set<LogLevel>? = nil, category: String? = nil) async -> [LogEntry] {
        var allEntries: [LogEntry] = logEntriesLock.withLock { self.logEntries }
        allEntries.sort { $0.timestamp > $1.timestamp }

        var filteredEntries = allEntries

        if let levels = levels, !levels.isEmpty {
            filteredEntries = filteredEntries.filter { levels.contains($0.level) }
        }

        if let category = category, !category.isEmpty {
            filteredEntries = filteredEntries.filter { $0.category == category }
        }

        if let searchText = searchText, !searchText.isEmpty {
            filteredEntries = filteredEntries.filter { entry in
                entry.message.localizedCaseInsensitiveContains(searchText) ||
                entry.level.description.localizedCaseInsensitiveContains(searchText) ||
                (entry.category?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (entry.metadata?.values.contains { $0.localizedCaseInsensitiveContains(searchText) } ?? false)
            }
        }

        return filteredEntries
    }
}

// MARK: - Gesture Recognition & Presentation

extension InAppLogViewer {

    private func setupGestureRecognition() {
        switch activationGesture {
        case .shake:
            setupShakeDetection()
        case .longPress:
            setupLongPressGesture()
        case .none:
            break
        }
    }

    private func tearDownGestureRecognition() {
        logViewerWindow?.isHidden = true
        logViewerWindow = nil
    }

    private func setupShakeDetection() {
        if logViewerWindow == nil {
            let window = LogViewerWindow(frame: UIScreen.main.bounds)
            window.backgroundColor = .clear
            window.isUserInteractionEnabled = false
            window.windowLevel = .alert + 1
            window.isHidden = false
            window.logViewer = self
            window.rootViewController = UIViewController()
            self.logViewerWindow = window
        }
    }

    private func setupLongPressGesture() {
        guard let keyWindow = getKeyWindow() else { return }

        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        longPressGesture.minimumPressDuration = 3.0
        keyWindow.addGestureRecognizer(longPressGesture)
    }

    private func getKeyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .first(where: { $0 is UIWindowScene })
            .flatMap { $0 as? UIWindowScene }?.windows
            .first(where: { $0.isKeyWindow })
    }

    @objc private func handleLongPress() {
        showLogViewer()
    }

    // MARK: - UI Presentation

    func showLogViewer() {
        guard isEnabled else { return }
        presentLogViewerUI()
    }

    private func presentLogViewerUI() {
        guard let rootViewController = getKeyWindow()?.rootViewController else {
            return
        }

        let topViewController = rootViewController.topMostViewController
        presentLogViewerScreen(from: topViewController)
    }

    private func presentLogViewerScreen(from viewController: UIViewController) {
        let logViewerVC = LogViewerViewController(logViewer: self)
        logViewerVC.logViewer = self
        let navController = UINavigationController(rootViewController: logViewerVC)

        if UIDevice.current.userInterfaceIdiom == .pad {
            navController.modalPresentationStyle = .formSheet
        } else {
            navController.modalPresentationStyle = .fullScreen
        }

        viewController.present(navController, animated: true)
    }
}
#endif
