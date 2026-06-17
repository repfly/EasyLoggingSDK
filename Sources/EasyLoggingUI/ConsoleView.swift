#if canImport(UIKit)
import EasyLoggingCore
import SwiftUI

struct ConsoleView: View {
    @ObservedObject var model: LogViewerModel

    var body: some View {
        VStack(spacing: 0) {
            LevelFilterBar(selectedLevels: $model.selectedLevels)
            Divider()
            if model.filteredLogs.isEmpty {
                EmptyStateView(text: "No log entries")
            } else {
                List(model.filteredLogs) { entry in
                    NavigationLink(destination: LogDetailView(entry: entry)) {
                        LogRow(entry: entry)
                    }
                }
                .listStyle(.plain)
            }
        }
        .searchable(text: $model.searchText, prompt: "Search logs")
    }
}

struct LevelFilterBar: View {
    @Binding var selectedLevels: Set<LogLevel>

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(allLogLevels, id: \.self) { level in
                    let isOn = selectedLevels.contains(level)
                    Button {
                        if isOn { selectedLevels.remove(level) } else { selectedLevels.insert(level) }
                    } label: {
                        Text(level.description.uppercased())
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(isOn ? color(for: level).opacity(0.2) : Color(.secondarySystemBackground))
                            .foregroundColor(isOn ? color(for: level) : .secondary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }
}

struct LogRow: View {
    let entry: InAppLogViewer.LogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.level.description.uppercased())
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(color(for: entry.level).opacity(0.2))
                    .foregroundColor(color(for: entry.level))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                Text(entry.formattedTimestamp)
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let category = entry.category {
                    Text(category)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Text(entry.message)
                .font(.callout)
                .lineLimit(2)
        }
        .padding(.vertical, 2)
    }
}

struct LogDetailView: View {
    let entry: InAppLogViewer.LogEntry

    var body: some View {
        List {
            Section("Overview") {
                LabeledRow(label: "Level", value: entry.level.description.uppercased())
                LabeledRow(label: "Time", value: entry.formattedTimestamp)
                if let category = entry.category {
                    LabeledRow(label: "Category", value: category)
                }
            }
            Section("Message") {
                Text(entry.message).font(.callout).textSelection(.enabled)
            }
            if let metadata = entry.metadata, !metadata.isEmpty {
                Section("Metadata") {
                    ForEach(metadata.keys.sorted(), id: \.self) { key in
                        LabeledRow(label: key, value: metadata[key] ?? "")
                    }
                }
            }
        }
        .navigationTitle("Log Detail")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LabeledRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label).foregroundColor(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing).textSelection(.enabled)
        }
        .font(.callout)
    }
}

struct EmptyStateView: View {
    let text: String

    var body: some View {
        VStack { Spacer(); Text(text).foregroundColor(.secondary); Spacer() }
            .frame(maxWidth: .infinity)
    }
}
#endif
