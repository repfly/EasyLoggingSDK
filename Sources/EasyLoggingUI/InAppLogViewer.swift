#if canImport(UIKit)
import UIKit
import SwiftUI
import EasyLoggingCore

/// A component that provides in-app log viewing capabilities for QA testing.
///
/// Most methods are `@MainActor` since they deal with UI. The `addLogEntry` method
/// is `nonisolated` and uses a lock because it's called from the logging actor.
@MainActor
public final class InAppLogViewer: LogSink {
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
    struct LogEntry: Identifiable {
        let id = UUID()
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

    public typealias ActivationGesture = EasyLoggingCore.ActivationGesture

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
    public nonisolated func addLogEntry(message: String, level: LogLevel, category: String? = nil, metadata: [String: String]? = nil) {
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

    func snapshotLogEntries() -> [LogEntry] {
        logEntriesLock.withLock { self.logEntries }
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
        let model = LogViewerModel(viewer: self)
        let hostingController = UIHostingController(
            rootView: LogViewerRootView(model: model) { [weak viewController] in
                viewController?.dismiss(animated: true)
            }
        )

        if UIDevice.current.userInterfaceIdiom == .pad {
            hostingController.modalPresentationStyle = .formSheet
        } else {
            hostingController.modalPresentationStyle = .fullScreen
        }

        viewController.present(hostingController, animated: true)
    }
}
#endif
