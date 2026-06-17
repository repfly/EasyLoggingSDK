#if canImport(UIKit)
import EasyLoggingCore
import EasyLoggingNetwork
import SwiftUI
import UIKit

struct NetworkListView: View {
    @ObservedObject var model: LogViewerModel

    var body: some View {
        VStack(spacing: 0) {
            Toggle("Failures only", isOn: $model.failuresOnly)
                .toggleStyle(.switch)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .font(.caption)
            Divider()
            if model.filteredNetwork.isEmpty {
                EmptyStateView(text: "No network requests")
            } else {
                List(model.filteredNetwork) { record in
                    NavigationLink(destination: NetworkDetailView(record: record)) {
                        NetworkRow(record: record)
                    }
                }
                .listStyle(.plain)
            }
        }
        .searchable(text: $model.searchText, prompt: "Search requests")
    }
}

struct NetworkRow: View {
    let record: NetworkRequestRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(record.method)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(color(forMethod: record.method).opacity(0.2))
                    .foregroundColor(color(forMethod: record.method))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                Text(record.statusText)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(color(forStatusCode: record.statusCode, isFailure: record.isFailure))
                Spacer()
                Text("\(Int(record.duration * 1000))ms")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(record.path.isEmpty ? record.url : record.path)
                .font(.callout)
                .lineLimit(1)
            if let host = record.host {
                Text(host).font(.caption).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct NetworkDetailView: View {
    let record: NetworkRequestRecord

    var body: some View {
        List {
            Section("Overview") {
                LabeledRow(label: "Method", value: record.method)
                LabeledRow(label: "Status", value: record.statusText)
                LabeledRow(label: "URL", value: record.url)
                LabeledRow(label: "Duration", value: "\(Int(record.duration * 1000)) ms")
                LabeledRow(label: "Request size", value: "\(record.requestSize) bytes")
                LabeledRow(label: "Response size", value: "\(record.responseSize) bytes")
                if let error = record.errorMessage {
                    LabeledRow(label: "Error", value: error)
                }
            }
            HeadersSection(title: "Request Headers", headers: record.requestHeaders)
            BodySection(title: "Request Body", content: record.prettyRequestBody)
            HeadersSection(title: "Response Headers", headers: record.responseHeaders)
            BodySection(title: "Response Body", content: record.prettyResponseBody)
            Section {
                Button {
                    UIPasteboard.general.string = record.curlCommand
                } label: {
                    Label("Copy as cURL", systemImage: "doc.on.doc")
                }
            }
        }
        .navigationTitle(record.statusText)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct HeadersSection: View {
    let title: String
    let headers: [String: String]

    var body: some View {
        if !headers.isEmpty {
            Section(title) {
                ForEach(headers.keys.sorted(), id: \.self) { key in
                    LabeledRow(label: key, value: headers[key] ?? "")
                }
            }
        }
    }
}

struct BodySection: View {
    let title: String
    let content: String?

    var body: some View {
        if let content {
            Section(title) {
                Text(content)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
    }
}
#endif
