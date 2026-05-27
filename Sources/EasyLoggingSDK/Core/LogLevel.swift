//
//  LogLevel.swift
//
//
//  Created by Yildirim, Alper on 16.08.2024.
//

import CocoaLumberjack

/// Represents different levels of logging, ordered by severity
public enum LogLevel: Int, Comparable, Equatable, Sendable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3

    /// String representation of the log level
    public var stringValue: String {
        switch self {
        case .debug: return "debug"
        case .info: return "info"
        case .warning: return "warning"
        case .error: return "error"
        }
    }

    /// The prefix to use in log messages
    public var logDescriptionPrefix: String {
        switch self {
        case .debug: return "🔍 DEBUG"
        case .info: return "ℹ️ INFO"
        case .warning: return "⚠️ WARNING"
        case .error: return "❌ ERROR"
        }
    }
    
    /// Convert to CocoaLumberjack log level
    public var ddLogLevel: DDLogLevel {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .warning
        case .error: return .error
        }
    }
    
    /// Convert to CocoaLumberjack log flag
    public var flag: DDLogFlag {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .warning
        case .error: return .error
        }
    }
    
    /// Convert from CocoaLumberjack log level
    public init(from ddLogLevel: DDLogLevel) {
        switch ddLogLevel {
        case .debug: self = .debug
        case .info: self = .info
        case .warning: self = .warning
        case .error: self = .error
        default: self = .info
        }
    }
    
    /// Create LogLevel from string (case insensitive)
    public static func fromString(_ string: String) -> LogLevel? {
        switch string.lowercased() {
        case "debug": return .debug
        case "info": return .info
        case "warning": return .warning
        case "error": return .error
        default: return nil
        }
    }

    /// Parses a level from formatted log output (emoji prefixes, bracket contents, etc.)
    static func fromLogOutput(_ string: String) -> LogLevel? {
        if let level = fromString(string) { return level }

        let normalized = string
            .replacingOccurrences(of: "🔍 ", with: "")
            .replacingOccurrences(of: "ℹ️ ", with: "")
            .replacingOccurrences(of: "⚠️ ", with: "")
            .replacingOccurrences(of: "❌ ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let level = fromString(normalized) { return level }

        for level in [LogLevel.debug, .info, .warning, .error] {
            if normalized.uppercased().contains(level.stringValue.uppercased()) {
                return level
            }
        }

        return nil
    }
    
    // Comparable based on severity (Int raw value)
    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
