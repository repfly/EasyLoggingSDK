#if canImport(UIKit)
import EasyLoggingCore
import EasyLoggingNetwork
import SwiftUI

@MainActor
final class LogViewerModel: ObservableObject {
    @Published var logEntries: [InAppLogViewer.LogEntry] = []
    @Published var networkRecords: [NetworkRequestRecord] = []
    @Published var searchText = ""
    @Published var selectedLevels: Set<LogLevel> = Set(allLogLevels)
    @Published var failuresOnly = false

    private weak var viewer: InAppLogViewer?

    init(viewer: InAppLogViewer?) {
        self.viewer = viewer
        refresh()
    }

    func refresh() {
        logEntries = viewer?.snapshotLogEntries() ?? []
        networkRecords = NetworkActivityStore.shared.snapshot()
    }

    var filteredLogs: [InAppLogViewer.LogEntry] {
        logEntries.reversed().filter { entry in
            guard selectedLevels.contains(entry.level) else { return false }
            guard !searchText.isEmpty else { return true }
            return entry.message.localizedCaseInsensitiveContains(searchText)
                || (entry.category?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var filteredNetwork: [NetworkRequestRecord] {
        networkRecords.reversed().filter { record in
            guard !failuresOnly || record.isFailure else { return false }
            guard !searchText.isEmpty else { return true }
            return record.url.localizedCaseInsensitiveContains(searchText)
                || record.method.localizedCaseInsensitiveContains(searchText)
        }
    }

    func clear() {
        viewer?.clearLogs()
        NetworkActivityStore.shared.clear()
        refresh()
    }

    func exportText() -> String {
        var lines = ["EasyLog session export", "", "== Console =="]
        for entry in logEntries {
            lines.append("[\(entry.level.description.uppercased())] \(entry.formattedTimestamp) \(entry.message)")
        }
        lines.append("")
        lines.append("== Network ==")
        for record in networkRecords {
            lines.append("\(record.method) \(record.url) → \(record.statusText) (\(Int(record.duration * 1000))ms)")
        }
        return lines.joined(separator: "\n")
    }
}

struct LogViewerRootView: View {
    @StateObject private var model: LogViewerModel
    private let onClose: () -> Void
    @State private var isExporting = false
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(model: LogViewerModel, onClose: @escaping () -> Void) {
        _model = StateObject(wrappedValue: model)
        self.onClose = onClose
    }

    var body: some View {
        NavigationView {
            TabView {
                ConsoleView(model: model)
                    .tabItem { Label("Console", systemImage: "list.bullet.rectangle") }
                NetworkListView(model: model)
                    .tabItem { Label("Network", systemImage: "network") }
            }
            .navigationTitle("EasyLog")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onClose)
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button { isExporting = true } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    Button(role: .destructive) { model.clear() } label: {
                        Image(systemName: "trash")
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .onReceive(ticker) { _ in model.refresh() }
        .sheet(isPresented: $isExporting) {
            ActivityView(items: [model.exportText()])
        }
    }
}
#endif
