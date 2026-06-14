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

    struct LogEntry {
        let timestamp: Date
        let level: LogLevel
        let message: String
        let category: String?
        let metadata: [String: String]?
        let source: LogSource

        enum LogSource {
            case memory
            case file
        }

        var formattedTimestamp: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"
            return formatter.string(from: timestamp)
        }

        var fullFormattedTimestamp: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
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

        var sourceIcon: String {
            switch source {
            case .memory: return "🔴"
            case .file: return "📁"
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
            metadata: metadata,
            source: .memory
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

// MARK: - Log Parsing & Filtering

extension InAppLogViewer {
    func loadLogEntriesFromFiles() async -> [LogEntry] {
        guard let logger = self.logger else { return [] }

        // The `DDFileLogger` stays on the actor; we only receive resolved file paths.
        let paths = await logger.getLogFilePaths()

        var allEntries: [LogEntry] = []
        for path in paths {
            let entries = parseLogFile(at: path)
            allEntries.append(contentsOf: entries)
        }

        return allEntries.sorted { $0.timestamp > $1.timestamp }
    }

    private func parseLogFile(at filePath: String) -> [LogEntry] {
        guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            return []
        }

        var entries: [LogEntry] = []
        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            if let entry = parseLogLine(line) {
                entries.append(entry)
            }
        }

        return entries
    }

    private func parseLogLine(_ line: String) -> LogEntry? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasPrefix("{"),
           let data = trimmed.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return parseJSONLogEntry(json)
        }

        if let entry = parseLegacyDatePrefixedLine(trimmed) {
            return entry
        }

        if let entry = parseISO8601PrefixedLine(trimmed) {
            return entry
        }

        if let entry = parseBracketPrefixedLine(trimmed) {
            return entry
        }

        if let entry = parseSimpleFormatLine(trimmed) {
            return entry
        }

        return nil
    }

    private func parseJSONLogEntry(_ json: [String: Any]) -> LogEntry? {
        guard let levelString = json["level"] as? String,
              let level = LogLevel.fromLogOutput(levelString),
              let message = json["message"] as? String else {
            return nil
        }

        let timestamp: Date
        if let timestampString = json["timestamp"] as? String {
            timestamp = Self.iso8601Formatter.date(from: timestampString) ?? Date()
        } else {
            timestamp = Date()
        }

        return LogEntry(
            timestamp: timestamp,
            level: level,
            message: message,
            category: json["category"] as? String,
            metadata: nil,
            source: .file
        )
    }

    private func parseLegacyDatePrefixedLine(_ line: String) -> LogEntry? {
        let components = line.components(separatedBy: " ")
        guard components.count >= 4 else { return nil }

        let dateString = "\(components[0]) \(components[1])"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        guard let timestamp = formatter.date(from: dateString) else { return nil }

        let levelString = components[2].trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        guard let level = LogLevel.fromLogOutput(levelString) else { return nil }

        let messageStartIndex = line.range(of: "] ")?.upperBound ?? line.startIndex
        let message = String(line[messageStartIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)

        return LogEntry(
            timestamp: timestamp,
            level: level,
            message: message,
            category: nil,
            metadata: nil,
            source: .file
        )
    }

    private func parseISO8601PrefixedLine(_ line: String) -> LogEntry? {
        guard let bracketRange = line.range(of: #"\[\s*[^\]]+\]"#, options: .regularExpression) else {
            return nil
        }

        let prefix = String(line[..<bracketRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let timestamp = Self.iso8601Formatter.date(from: prefix) else { return nil }

        let levelString = String(line[bracketRange]).trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        guard let level = LogLevel.fromLogOutput(levelString) else { return nil }

        let messageStartIndex = bracketRange.upperBound
        let message = String(line[messageStartIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)

        return LogEntry(
            timestamp: timestamp,
            level: level,
            message: message,
            category: nil,
            metadata: nil,
            source: .file
        )
    }

    private func parseBracketPrefixedLine(_ line: String) -> LogEntry? {
        guard line.hasPrefix("["),
              let closingIndex = line.firstIndex(of: "]") else {
            return nil
        }

        let levelString = String(line[line.index(after: line.startIndex)..<closingIndex])
        guard let level = LogLevel.fromLogOutput(levelString) else { return nil }

        let messageStartIndex = line.index(after: closingIndex)
        let message = String(line[messageStartIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)

        return LogEntry(
            timestamp: Date(),
            level: level,
            message: message,
            category: nil,
            metadata: nil,
            source: .file
        )
    }

    private func parseSimpleFormatLine(_ line: String) -> LogEntry? {
        guard let colonIndex = line.firstIndex(of: ":") else { return nil }

        let levelPart = String(line[..<colonIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let level = LogLevel.fromLogOutput(levelPart) else { return nil }

        let message = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return nil }

        return LogEntry(
            timestamp: Date(),
            level: level,
            message: message,
            category: nil,
            metadata: nil,
            source: .file
        )
    }

    // `nonisolated(unsafe)`: ISO8601DateFormatter is not Sendable, but this instance is immutable
    // after creation and is only used for thread-safe `string(from:)`/`date(from:)` formatting.
    nonisolated(unsafe) private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// Get all log entries (memory + files) with optional filtering
    func getAllLogEntries(searchText: String? = nil, levels: Set<LogLevel>? = nil, category: String? = nil) async -> [LogEntry] {
        var allEntries: [LogEntry] = []

        logEntriesLock.withLock {
            allEntries.append(contentsOf: self.logEntries)
        }

        allEntries.append(contentsOf: await loadLogEntriesFromFiles())
        allEntries = removeDuplicateEntries(allEntries)
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

    private func removeDuplicateEntries(_ entries: [LogEntry]) -> [LogEntry] {
        var uniqueEntries: [LogEntry] = []
        var seenKeys: Set<String> = []

        for entry in entries {
            let key = "\(entry.timestamp.timeIntervalSince1970)_\(entry.message)"
            if !seenKeys.contains(key) {
                seenKeys.insert(key)
                uniqueEntries.append(entry)
            }
        }

        return uniqueEntries
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
