//
//  InAppLogViewerUI.swift
//
//  UI components for InAppLogViewer — extracted for file length compliance.
//

#if canImport(UIKit)
import UIKit

// MARK: - Log Viewer Window

final class LogViewerWindow: UIWindow {
    weak var logViewer: InAppLogViewer?

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        guard motion == .motionShake else { return }
        logViewer?.showLogViewer()
    }
}

// MARK: - Log Viewer View Controller

final class LogViewerViewController: UIViewController,
    UITableViewDataSource,
    UITableViewDelegate,
    UISearchResultsUpdating {

    private var allLogEntries: [InAppLogViewer.LogEntry] = []
    private let tableView = UITableView()
    private var filteredEntries: [InAppLogViewer.LogEntry] = []
    private var selectedLevels: Set<LogLevel> = [.debug, .info, .warning, .error]
    private var searchText: String = ""
    private let searchController = UISearchController(searchResultsController: nil)
    weak var logViewer: InAppLogViewer?

    func updateSearchResults(for searchController: UISearchController) {
        searchText = searchController.searchBar.text ?? ""
        applyFilters()
    }

    init(logViewer: InAppLogViewer) {
        self.logViewer = logViewer
        super.init(nibName: nil, bundle: nil)
        loadAllLogEntries()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func loadAllLogEntries() {
        guard let logViewer = self.logViewer else { return }

        let loadingIndicator = UIActivityIndicatorView(style: .medium)
        loadingIndicator.startAnimating()
        self.navigationItem.titleView = loadingIndicator

        Task { @MainActor in
            let entries = await logViewer.getAllLogEntries(
                searchText: self.searchText.isEmpty ? nil : self.searchText,
                levels: self.selectedLevels
            )

            self.allLogEntries = entries
            self.filteredEntries = entries
            self.tableView.reloadData()
            self.navigationItem.titleView = nil
            self.title = "QA Log Viewer (\(self.allLogEntries.count) entries)"
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "QA Log Viewer (\(allLogEntries.count) entries)"
        view.backgroundColor = .systemBackground

        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search logs..."
        navigationItem.searchController = searchController
        definesPresentationContext = true

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Close", style: .done,
            target: self, action: #selector(closeButtonTapped)
        )

        let filterButton = UIBarButtonItem(
            title: "Filter", style: .plain,
            target: self, action: #selector(filterButtonTapped)
        )
        let shareButton = UIBarButtonItem(
            barButtonSystemItem: .action,
            target: self, action: #selector(shareButtonTapped)
        )
        navigationItem.rightBarButtonItems = [filterButton, shareButton]

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80
        tableView.register(LogEntryCell.self, forCellReuseIdentifier: "LogEntryCell")
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        loadAllLogEntries()
    }

    private func applyFilters() {
        guard let logViewer = self.logViewer else { return }
        let searchQuery = searchText.isEmpty ? nil : searchText
        let levelFilter = selectedLevels.isEmpty ? nil : selectedLevels
        Task { @MainActor in
            self.filteredEntries = await logViewer.getAllLogEntries(
                searchText: searchQuery,
                levels: levelFilter
            )
            self.tableView.reloadData()
            self.title = "QA Log Viewer (\(self.filteredEntries.count) entries)"
        }
    }

    @objc private func closeButtonTapped() { dismiss(animated: true) }

    @objc private func shareButtonTapped() {
        Task { @MainActor in
            if let logger = self.logViewer?.currentLogger,
               let logFileURL = await logger.getCurrentLogFileURL() {
                self.shareLogFile(logFileURL)
            } else {
                self.shareLogEntries()
            }
        }
    }

    private func shareLogFile(_ logFileURL: URL) {
        let tempDir = FileManager.default.temporaryDirectory
        let appName = Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String ?? "App"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let tempFileURL = tempDir.appendingPathComponent(
            "\(appName)_logs_\(dateFormatter.string(from: Date())).log"
        )

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                if FileManager.default.fileExists(atPath: tempFileURL.path) {
                    try FileManager.default.removeItem(at: tempFileURL)
                }
                try FileManager.default.copyItem(at: logFileURL, to: tempFileURL)
                DispatchQueue.main.async {
                    let activityVC = UIActivityViewController(
                        activityItems: [tempFileURL], applicationActivities: nil
                    )
                    if let popover = activityVC.popoverPresentationController {
                        popover.barButtonItem = self.navigationItem.rightBarButtonItems?.last
                    }
                    self.present(activityVC, animated: true)
                }
            } catch {
                DispatchQueue.main.async { self.shareLogEntries() }
            }
        }
    }

    private func shareLogEntries() {
        var logText = "Log Entries\n\n"
        for entry in filteredEntries {
            logText += "[\(entry.level.stringValue.uppercased())] "
            logText += "[\(entry.formattedTimestamp)] \(entry.message)\n"
            if let metadata = entry.metadata, !metadata.isEmpty {
                logText += "Metadata: \(metadata)\n"
            }
            logText += "\n"
        }
        let activityVC = UIActivityViewController(
            activityItems: [logText], applicationActivities: nil
        )
        if let popover = activityVC.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItems?.last
        }
        present(activityVC, animated: true)
    }

    @objc private func filterButtonTapped() {
        let alert = UIAlertController(
            title: "Filter Logs",
            message: "Select log levels to display",
            preferredStyle: .actionSheet
        )
        for level in [LogLevel.debug, .info, .warning, .error] {
            let isSelected = selectedLevels.contains(level)
            alert.addAction(UIAlertAction(
                title: "\(isSelected ? "✓ " : "")Show \(level.stringValue.capitalized)",
                style: .default
            ) { [weak self] _ in
                guard let self else { return }
                if isSelected {
                    self.selectedLevels.remove(level)
                } else {
                    self.selectedLevels.insert(level)
                }
                self.applyFilters()
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItems?.first
        }
        present(alert, animated: true)
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredEntries.count
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: "LogEntryCell", for: indexPath
        ) as? LogEntryCell else {
            return UITableViewCell()
        }
        cell.configure(with: filteredEntries[indexPath.row])
        return cell
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let detailVC = LogDetailViewController(logEntry: filteredEntries[indexPath.row])
        navigationController?.pushViewController(detailVC, animated: true)
    }
}

// MARK: - Log Entry Cell

final class LogEntryCell: UITableViewCell {
    private let levelLabel = UILabel()
    private let timestampLabel = UILabel()
    private let messageLabel = UILabel()
    private let sourceLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        levelLabel.translatesAutoresizingMaskIntoConstraints = false
        levelLabel.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        levelLabel.textAlignment = .center
        levelLabel.layer.cornerRadius = 4
        levelLabel.layer.masksToBounds = true
        contentView.addSubview(levelLabel)

        sourceLabel.translatesAutoresizingMaskIntoConstraints = false
        sourceLabel.font = UIFont.systemFont(ofSize: 14)
        contentView.addSubview(sourceLabel)

        timestampLabel.translatesAutoresizingMaskIntoConstraints = false
        timestampLabel.font = UIFont.systemFont(ofSize: 12)
        timestampLabel.textColor = .secondaryLabel
        contentView.addSubview(timestampLabel)

        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.font = UIFont.systemFont(ofSize: 14)
        messageLabel.numberOfLines = 2
        contentView.addSubview(messageLabel)

        NSLayoutConstraint.activate([
            levelLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            levelLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            levelLabel.widthAnchor.constraint(equalToConstant: 60),
            levelLabel.heightAnchor.constraint(equalToConstant: 20),
            sourceLabel.centerYAnchor.constraint(equalTo: levelLabel.centerYAnchor),
            sourceLabel.leadingAnchor.constraint(equalTo: levelLabel.trailingAnchor, constant: 8),
            sourceLabel.widthAnchor.constraint(equalToConstant: 25),
            timestampLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            timestampLabel.leadingAnchor.constraint(equalTo: sourceLabel.trailingAnchor, constant: 8),
            timestampLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            messageLabel.topAnchor.constraint(equalTo: levelLabel.bottomAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            messageLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }

    func configure(with entry: InAppLogViewer.LogEntry) {
        levelLabel.text = entry.level.stringValue.uppercased()
        levelLabel.backgroundColor = entry.levelColor.withAlphaComponent(0.2)
        levelLabel.textColor = entry.levelColor
        sourceLabel.text = entry.sourceIcon
        timestampLabel.text = entry.source == .file
            ? entry.fullFormattedTimestamp : entry.formattedTimestamp
        messageLabel.text = entry.message
        accessoryType = .disclosureIndicator
    }
}

// MARK: - Log Detail View Controller

final class LogDetailViewController: UIViewController {
    private let logEntry: InAppLogViewer.LogEntry
    private let scrollView = UIScrollView()
    private let contentView = UIView()

    init(logEntry: InAppLogViewer.LogEntry) {
        self.logEntry = logEntry
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Log Details"
        view.backgroundColor = .systemBackground
        setupScrollView()
        layoutContent()
    }

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }

    private func layoutContent() {
        let headerView = createHeaderView()
        contentView.addSubview(headerView)
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])

        var lastView: UIView = headerView

        let messageLabel = createSectionLabel(title: "Message")
        let messageText = createTextView(text: logEntry.message)
        contentView.addSubview(messageLabel)
        contentView.addSubview(messageText)
        NSLayoutConstraint.activate([
            messageLabel.topAnchor.constraint(equalTo: lastView.bottomAnchor, constant: 16),
            messageLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            messageText.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 8),
            messageText.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            messageText.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
        lastView = messageText

        if let metadata = logEntry.metadata, !metadata.isEmpty {
            let metaLabel = createSectionLabel(title: "Metadata")
            let metaText = createTextView(text: formatMetadata(metadata))
            contentView.addSubview(metaLabel)
            contentView.addSubview(metaText)
            NSLayoutConstraint.activate([
                metaLabel.topAnchor.constraint(equalTo: lastView.bottomAnchor, constant: 16),
                metaLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
                metaLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
                metaText.topAnchor.constraint(equalTo: metaLabel.bottomAnchor, constant: 8),
                metaText.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
                metaText.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
            ])
            lastView = metaText
        }

        let shareButton = UIButton(type: .system)
        shareButton.translatesAutoresizingMaskIntoConstraints = false
        shareButton.setTitle("Share Log Entry", for: .normal)
        shareButton.addTarget(self, action: #selector(shareButtonTapped), for: .touchUpInside)
        contentView.addSubview(shareButton)
        NSLayoutConstraint.activate([
            shareButton.topAnchor.constraint(equalTo: lastView.bottomAnchor, constant: 24),
            shareButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            shareButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24)
        ])
    }

    private func createHeaderView() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        let badge = UILabel()
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.text = logEntry.level.stringValue.uppercased()
        badge.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        badge.textAlignment = .center
        badge.backgroundColor = logEntry.levelColor.withAlphaComponent(0.2)
        badge.textColor = logEntry.levelColor
        badge.layer.cornerRadius = 4
        badge.layer.masksToBounds = true
        container.addSubview(badge)
        let timestamp = UILabel()
        timestamp.translatesAutoresizingMaskIntoConstraints = false
        timestamp.text = "Time: \(logEntry.formattedTimestamp)"
        timestamp.font = UIFont.systemFont(ofSize: 14)
        timestamp.textColor = .secondaryLabel
        container.addSubview(timestamp)
        NSLayoutConstraint.activate([
            badge.topAnchor.constraint(equalTo: container.topAnchor),
            badge.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            badge.widthAnchor.constraint(equalToConstant: 80),
            badge.heightAnchor.constraint(equalToConstant: 24),
            timestamp.topAnchor.constraint(equalTo: badge.bottomAnchor, constant: 8),
            timestamp.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            timestamp.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            timestamp.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }

    private func createSectionLabel(title: String) -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = title
        label.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        return label
    }

    private func createTextView(text: String) -> UITextView {
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.text = text
        textView.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        textView.isEditable = false
        textView.backgroundColor = .secondarySystemBackground
        textView.layer.cornerRadius = 8
        textView.isScrollEnabled = false
        let fixedWidth = UIScreen.main.bounds.width - 32
        let size = textView.sizeThatFits(
            CGSize(width: fixedWidth, height: CGFloat.greatestFiniteMagnitude)
        )
        textView.heightAnchor.constraint(equalToConstant: min(size.height, 300)).isActive = true
        return textView
    }

    private func formatMetadata(_ metadata: [String: String]) -> String {
        metadata.keys.sorted().map { "\($0): \(metadata[$0] ?? "")" }.joined(separator: "\n")
    }

    @objc private func shareButtonTapped() {
        var shareText = """
        Level: \(logEntry.level.stringValue.uppercased())
        Time: \(logEntry.formattedTimestamp)
        Message: \(logEntry.message)
        """
        if let metadata = logEntry.metadata, !metadata.isEmpty {
            shareText += "\n\nMetadata:\n\(formatMetadata(metadata))"
        }
        let activityVC = UIActivityViewController(
            activityItems: [shareText], applicationActivities: nil
        )
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(
                x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0
            )
            popover.permittedArrowDirections = []
        }
        present(activityVC, animated: true)
    }
}

// MARK: - UIViewController Extension

extension UIViewController {
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
#endif
