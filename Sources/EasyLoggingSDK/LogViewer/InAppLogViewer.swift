//
//  InAppLogViewer.swift
//
//
//  Created by Yildirim, Alper on 25.08.2024.
//

#if canImport(UIKit)
import UIKit

/// A component that provides in-app log viewing capabilities for QA testing
public final class InAppLogViewer {
    // MARK: - Properties
    
    private weak var logger: EasyLogger?
    private var isEnabled: Bool = false
    private var activationGesture: ActivationGesture = .shake
    private var accessCode: String?
    private var logViewerWindow: UIWindow?
    private var maxLogEntries: Int = 1000
    private var logEntries: [LogEntry] = [] // In-memory logs for current session
    private let logEntriesLock = UnfairLock()
    private let queue = DispatchQueue(label: "com.easyloggingsdk.inapplogviewer", qos: .userInitiated)
    
    // Accessor for the logger property
    var currentLogger: EasyLogger? {
        return logger
    }
    
    // MARK: - Types
    
    /// Represents a single log entry in the viewer
    struct LogEntry {
        let timestamp: Date
        let level: LogLevel
        let message: String
        let category: String?
        let metadata: [String: String]?
        let source: LogSource
        
        enum LogSource {
            case memory // Current session
            case file   // From log files
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
            case .debug: return .systemGray
            case .info: return .systemBlue
            case .warning: return .systemOrange
            case .error: return .systemRed
            }
        }
        
        var sourceIcon: String {
            switch source {
            case .memory: return "🔴" // Live
            case .file: return "📁"   // File
            }
        }
    }
    
    /// Kept as typealias for backwards compatibility
    public typealias ActivationGesture = EasyLoggingSDK.ActivationGesture
    
    // MARK: - Initialization
    
    init(logger: EasyLogger) {
        self.logger = logger
    }
    
    // MARK: - Configuration
    
    /// Configure the in-app log viewer
    /// - Parameters:
    ///   - isEnabled: Whether the log viewer is enabled
    ///   - activationGesture: How to activate the log viewer
    ///   - accessCode: Optional access code for security
    ///   - maxLogEntries: Maximum number of log entries to keep in memory
    func configure(isEnabled: Bool, activationGesture: ActivationGesture, accessCode: String?, maxLogEntries: Int) {
        self.isEnabled = isEnabled
        self.activationGesture = activationGesture
        self.accessCode = accessCode
        self.maxLogEntries = maxLogEntries
        
        if isEnabled {
            setupGestureRecognition()
        } else {
            tearDownGestureRecognition()
        }
    }
    
    // MARK: - Log Management
    
    /// Add a log entry to the in-memory collection (current session only)
    /// - Parameters:
    ///   - message: The log message
    ///   - level: The log level
    ///   - metadata: Optional metadata associated with the log
    func addLogEntry(message: String, level: LogLevel, category: String? = nil, metadata: [String: String]? = nil) {
        guard isEnabled else { return }
        
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

            // Trim if we exceed the maximum number of entries
            if self.logEntries.count > self.maxLogEntries {
                self.logEntries.removeFirst(self.logEntries.count - self.maxLogEntries)
            }
        }
    }

    /// Clear all in-memory log entries
    func clearLogs() {
        logEntriesLock.withLock {
            self.logEntries.removeAll()
        }
    }
    
}

// MARK: - Log Parsing & Filtering

extension InAppLogViewer {
    /// Load log entries from files (lazy loading)
    func loadLogEntriesFromFiles() -> [LogEntry] {
        guard let logger = self.logger else { return [] }
        
        var allEntries: [LogEntry] = []
        
        // Get log file manager
        guard let fileLogger = logger.internalFileLogger else {
            return []
        }
        
        let logFileManager = fileLogger.logFileManager
        
        // Get all log files sorted by date (newest first)
        let logFileInfos = logFileManager.sortedLogFileInfos
        
        for logFileInfo in logFileInfos {
            let entries = parseLogFile(at: logFileInfo.filePath)
            allEntries.append(contentsOf: entries)
        }
        
        // Sort by timestamp (newest first)
        return allEntries.sorted { $0.timestamp > $1.timestamp }
    }
    
    /// Parse a log file and extract log entries
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
    
    /// Parse a single log line and create a LogEntry
    private func parseLogLine(_ line: String) -> LogEntry? {
        // Skip empty lines
        guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        
        // Try to extract timestamp, level, and message
        // Expected format: "2025-01-11 14:17:09.965 [DEBUG] Message here"
        let components = line.components(separatedBy: " ")
        guard components.count >= 4 else { return nil }
        
        // Parse timestamp
        let dateString = "\(components[0]) \(components[1])"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        guard let timestamp = formatter.date(from: dateString) else { return nil }
        
        // Parse level
        let levelString = components[2].trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        guard let level = LogLevel.fromString(levelString) else { return nil }
        
        // Extract message (everything after the level)
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
    
    /// Get all log entries (memory + files) with optional filtering
    func getAllLogEntries(searchText: String? = nil, levels: Set<LogLevel>? = nil, category: String? = nil) -> [LogEntry] {
        // Combine memory and file entries
        var allEntries: [LogEntry] = []
        
        // Add in-memory entries (current session)
        logEntriesLock.withLock {
            allEntries.append(contentsOf: self.logEntries)
        }
        
        // Add file entries (historical)
        allEntries.append(contentsOf: loadLogEntriesFromFiles())
        
        // Remove duplicates (in case current session logs are also in files)
        allEntries = removeDuplicateEntries(allEntries)
        
        // Sort by timestamp (newest first)
        allEntries.sort { $0.timestamp > $1.timestamp }
        
        // Apply filters
        var filteredEntries = allEntries
        
        // Filter by log levels
        if let levels = levels, !levels.isEmpty {
            filteredEntries = filteredEntries.filter { levels.contains($0.level) }
        }
        
        // Filter by category
        if let category = category, !category.isEmpty {
            filteredEntries = filteredEntries.filter { $0.category == category }
        }

        // Filter by search text
        if let searchText = searchText, !searchText.isEmpty {
            filteredEntries = filteredEntries.filter { entry in
                entry.message.localizedCaseInsensitiveContains(searchText) ||
                entry.level.stringValue.localizedCaseInsensitiveContains(searchText) ||
                (entry.category?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (entry.metadata?.values.contains { $0.localizedCaseInsensitiveContains(searchText) } ?? false)
            }
        }
        
        return filteredEntries
    }
    
    /// Remove duplicate entries based on timestamp and message
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
            // Shake is handled by the window
            setupShakeDetection()
        case .longPress:
            setupLongPressGesture()
        case .none:
            break // No gesture recognition setup needed
        }
    }
    
    private func tearDownGestureRecognition() {
        // Remove any gesture recognizers
        logViewerWindow?.isHidden = true
        logViewerWindow = nil
    }
    
    private func setupShakeDetection() {
        if logViewerWindow == nil {
            DispatchQueue.main.async {
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
    }
    
    private func setupLongPressGesture() {
        guard let keyWindow = getKeyWindow() else { return }
        
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        longPressGesture.minimumPressDuration = 3.0
        keyWindow.addGestureRecognizer(longPressGesture)
    }

    private func getKeyWindow() -> UIWindow? {
        if #available(iOS 15.0, *) {
            return UIApplication.shared.connectedScenes
                .filter { $0.activationState == .foregroundActive }
                .first(where: { $0 is UIWindowScene })
                .flatMap { $0 as? UIWindowScene }?.windows
                .first(where: { $0.isKeyWindow })
        } else {
            return UIApplication.shared.windows.first(where: { $0.isKeyWindow })
        }
    }
    
    @objc private func handleLongPress() {
        showLogViewer()
    }
    
    // MARK: - UI Presentation
    
    /// Show the log viewer UI
    func showLogViewer() {
        guard isEnabled else { return }
        
        DispatchQueue.main.async {
            self.presentLogViewerUI()
        }
    }
    
    private func presentLogViewerUI() {
        // Get the top view controller to present from
        guard let rootViewController = getKeyWindow()?.rootViewController else {
            return
        }
        
        let topViewController = rootViewController.topMostViewController
        
        // If access code is required, show the access code screen first
        if let accessCode = self.accessCode, !accessCode.isEmpty {
            presentAccessCodeScreen(from: topViewController)
        } else {
            presentLogViewerScreen(from: topViewController)
        }
    }
    
    private func presentAccessCodeScreen(from viewController: UIViewController) {
        let alertController = UIAlertController(
            title: "QA Log Viewer",
            message: "Enter access code to view logs",
            preferredStyle: .alert
        )
        
        alertController.addTextField { textField in
            textField.placeholder = "Access Code"
            textField.isSecureTextEntry = true
            textField.keyboardType = .numberPad
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        let submitAction = UIAlertAction(title: "Submit", style: .default) { [weak self, weak alertController] _ in
            guard let self = self,
                  let textField = alertController?.textFields?.first,
                  let enteredCode = textField.text,
                  enteredCode == self.accessCode else {

                let errorAlert = UIAlertController(
                    title: "Invalid Code",
                    message: "The access code you entered is incorrect.",
                    preferredStyle: .alert
                )
                errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                viewController.present(errorAlert, animated: true)
                return
            }

            self.presentLogViewerScreen(from: viewController)
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(submitAction)
        
        viewController.present(alertController, animated: true)
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
    
    @objc private func shareButtonTapped() {
        // First try to share the current log file
        if let logger = self.logger,
           let logFileURL = logger.currentLogFileURL {
            
            shareLogFile(logFileURL)
        } else {
            // If we can't get the log file, share the current log entries as text
            shareLogEntries()
        }
    }
    
    private func shareLogFile(_ logFileURL: URL) {
        let tempDir = FileManager.default.temporaryDirectory
        let appName = Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String ?? "App"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let dateString = dateFormatter.string(from: Date())
        let tempFileURL = tempDir.appendingPathComponent("\(appName)_logs_\(dateString).log")
        
        do {
            if FileManager.default.fileExists(atPath: tempFileURL.path) {
                try FileManager.default.removeItem(at: tempFileURL)
            }
            try FileManager.default.copyItem(at: logFileURL, to: tempFileURL)

            let activityVC = UIActivityViewController(
                activityItems: [tempFileURL],
                applicationActivities: nil
            )

            if let rootViewController = getKeyWindow()?.rootViewController {
               let topViewController = rootViewController.topMostViewController
                if let popover = activityVC.popoverPresentationController {
                    popover.sourceView = topViewController.view
                    popover.sourceRect = CGRect(x: topViewController.view.bounds.midX, y: topViewController.view.bounds.midY, width: 0, height: 0)
                    popover.permittedArrowDirections = []
                }
                
                topViewController.present(activityVC, animated: true)
            }
        } catch {
            // If file operations fail, fall back to sharing log entries as text
            shareLogEntries()
        }
    }
    
    private func shareLogEntries() {
        var logText = "Log Entries\n\n"
        
        queue.sync {
            for entry in self.logEntries {
                logText += "[\(entry.level.stringValue.uppercased())] [\(entry.formattedTimestamp)] \(entry.message)\n"
                
                if let metadata = entry.metadata, !metadata.isEmpty {
                    logText += "Metadata: \(metadata)\n"
                }
                
                logText += "\n"
            }
        }
        
        let activityVC = UIActivityViewController(
            activityItems: [logText],
            applicationActivities: nil
        )
        
        // Present the share sheet
        if let rootViewController = getKeyWindow()?.rootViewController {
           let topViewController = rootViewController.topMostViewController
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = topViewController.view
                popover.sourceRect = CGRect(x: topViewController.view.bounds.midX, y: topViewController.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            topViewController.present(activityVC, animated: true)
        }
    }
}
#endif
