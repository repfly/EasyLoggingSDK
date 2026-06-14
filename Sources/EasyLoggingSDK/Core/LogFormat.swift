//
//  EasyLogFormat.swift
//
//
//  Created by Yildirim, Alper on 16.08.2024.
//
import Foundation

/// Defines the format of log messages
public struct LogFormat: Sendable {
    /// Backing kind that determines how a record is rendered.
    private enum Kind: Sendable {
        case template(String)
        case json
    }

    /// The rendering strategy for this format.
    private let kind: Kind

    /// Cached date formatter shared across all LogFormat instances (nonisolated(unsafe) is safe
    /// because ISO8601DateFormatter is thread-safe and we never mutate the instance after creation).
    nonisolated(unsafe) private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// Cached JSON encoder shared across all LogFormat instances. `JSONEncoder` is `Sendable`
    /// and thread-safe once configured, and we never mutate it after creation.
    private static let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        return encoder
    }()

    /// Creates a new log format with the specified template
    /// - Parameter template: The template string used to format log messages
    public init(template: String) {
        self.kind = .template(template)
    }

    /// Private initializer used by presets to select a non-template rendering kind.
    private init(kind: Kind) {
        self.kind = kind
    }

    /// Formats a log message using the configured rendering strategy.
    public func format(
        message: String,
        level: LogLevel,
        metadata: [String: String]?,
        category: String?,
        file: String,
        function: String,
        line: Int
    ) -> String {
        switch kind {
        case .template(let template):
            return renderTemplate(
                template,
                message: message,
                level: level,
                metadata: metadata,
                category: category,
                file: file,
                function: function,
                line: line
            )
        case .json:
            return renderJSON(
                message: message,
                level: level,
                metadata: metadata,
                category: category,
                file: file,
                function: function,
                line: line
            )
        }
    }

    // MARK: - Template Rendering

    /// Single-pass template renderer.
    ///
    /// Scans the template once, left to right. When a known placeholder token is found (longest
    /// match first, e.g. `%levelRaw` before `%level`), its resolved value is emitted directly into
    /// the output and scanning resumes past the token. Resolved values are never re-scanned, so
    /// user-supplied content containing tokens like `%level` cannot corrupt the output. Unknown
    /// `%` tokens are emitted verbatim.
    private func renderTemplate(
        _ template: String,
        message: String,
        level: LogLevel,
        metadata: [String: String]?,
        category: String?,
        file: String,
        function: String,
        line: Int
    ) -> String {
        // Ordered longest-first so the matcher resolves %levelRaw before %level.
        let placeholders: [(token: String, value: String)] = [
            ("%levelRaw", level.stringValue),
            ("%level", Self.decoratedLevel(level)),
            ("%category", category ?? ""),
            ("%metadata", formatMetadata(metadata)),
            ("%message", message),
            ("%function", function),
            ("%file", (file as NSString).lastPathComponent),
            ("%line", String(line)),
            ("%date", Self.iso8601Formatter.string(from: Date()))
        ]

        var output = ""
        output.reserveCapacity(template.count)

        var index = template.startIndex
        let end = template.endIndex

        while index < end {
            if template[index] == "%" {
                var matched = false
                for placeholder in placeholders where matches(placeholder.token, in: template, at: index) {
                    output += placeholder.value
                    index = template.index(index, offsetBy: placeholder.token.count)
                    matched = true
                    break
                }
                if matched { continue }
            }

            output.append(template[index])
            index = template.index(after: index)
        }

        return output
    }

    /// Returns true when `token` occurs in `source` starting exactly at `position`.
    private func matches(_ token: String, in source: String, at position: String.Index) -> Bool {
        var sourceIndex = position
        var tokenIndex = token.startIndex
        let sourceEnd = source.endIndex
        let tokenEnd = token.endIndex

        while tokenIndex < tokenEnd {
            guard sourceIndex < sourceEnd, source[sourceIndex] == token[tokenIndex] else {
                return false
            }
            sourceIndex = source.index(after: sourceIndex)
            tokenIndex = token.index(after: tokenIndex)
        }
        return true
    }

    // MARK: - JSON Rendering

    /// Encodable payload for the `.json` format. Optional fields are omitted when absent.
    private struct JSONPayload: Encodable {
        let timestamp: String
        let level: String
        let file: String
        let line: Int
        let function: String
        let message: String
        let category: String?
        let metadata: [String: String]?
    }

    /// Builds one valid JSON object per log line. All string values are escaped by `JSONEncoder`,
    /// so hostile content (quotes, backslashes, newlines) cannot break the output.
    private func renderJSON(
        message: String,
        level: LogLevel,
        metadata: [String: String]?,
        category: String?,
        file: String,
        function: String,
        line: Int
    ) -> String {
        let trimmedCategory = category?.isEmpty == true ? nil : category
        let payloadMetadata = (metadata?.isEmpty == false) ? metadata : nil

        let payload = JSONPayload(
            timestamp: Self.iso8601Formatter.string(from: Date()),
            level: level.stringValue,
            file: (file as NSString).lastPathComponent,
            line: line,
            function: function,
            message: message,
            category: trimmedCategory,
            metadata: payloadMetadata
        )

        guard let data = try? Self.jsonEncoder.encode(payload),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    // MARK: - Presentation Helpers

    /// Renders the decorated `%level` value (emoji + uppercased name). This is presentation and
    /// deliberately lives in the formatter rather than on the `LogLevel` domain enum.
    private static func decoratedLevel(_ level: LogLevel) -> String {
        switch level {
        case .debug: return "🔍 DEBUG"
        case .info: return "ℹ️ INFO"
        case .warning: return "⚠️ WARNING"
        case .error: return "❌ ERROR"
        }
    }

    private func formatMetadata(_ metadata: [String: String]?) -> String {
        guard let metadata = metadata, !metadata.isEmpty else { return "" }
        return metadata.map { "[\($0.key):\($0.value)]" }.joined(separator: " ")
    }
}

// MARK: - Predefined Formats

public extension LogFormat {
    /// Default log format: "[LEVEL] File:Line Function - Message Metadata"
    static let `default` = LogFormat(
        template: "[%level] %file:%line %function - %message %metadata"
    )

    /// Simple format: "LEVEL: Message"
    static let simple = LogFormat(
        template: "%level: %message"
    )

    /// Detailed format with timestamp: "YYYY-MM-DD HH:mm:ss [LEVEL] File:Line Function - Message Metadata"
    static let detailed = LogFormat(
        template: "%date [%level] %file:%line %function - %message %metadata"
    )

    /// Structured JSON format. Emits one valid JSON object per log line.
    static let json = LogFormat(kind: .json)

    /// Clean format for internal SDK logging: "[LEVEL] Message Metadata"
    static let clean = LogFormat(
        template: "[%level] %message %metadata"
    )
}
