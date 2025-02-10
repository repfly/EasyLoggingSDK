//
//  EasyLogFormat.swift
//
//
//  Created by Yildirim, Alper on 16.08.2024.
//
import Foundation

/// Defines the format of log messages
public struct LogFormat {
    /// The template string used to format log messages
    private let template: String
    
    /// Creates a new log format with the specified template
    /// - Parameter template: The template string used to format log messages
    public init(template: String) {
        self.template = template
    }
    
    /// Formats a log message using the template
    public func format(
        message: String,
        level: LogLevel,
        metadata: [String: String]?,
        file: String,
        function: String,
        line: Int
    ) -> String {
        var result = template
        
        // Replace placeholders with actual values
        let replacements: [String: String] = [
            "%message": message,
            "%level": level.logDescriptionPrefix,
            "%levelRaw": String(level.rawValue),
            "%file": (file as NSString).lastPathComponent,
            "%function": function,
            "%line": String(line),
            "%date": ISO8601DateFormatter().string(from: Date()),
            "%metadata": formatMetadata(metadata)
        ]
        
        for (key, value) in replacements {
            result = result.replacingOccurrences(of: key, with: value)
        }
        
        return result
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
    
    /// JSON-like format
    static let json = LogFormat(
        template: """
        {"timestamp":"%date","level":"%levelRaw","file":"%file","line":%line,"function":"%function","message":"%message"}
        """
    )
}
