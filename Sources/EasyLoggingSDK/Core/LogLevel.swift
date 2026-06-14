//
//  LogLevel.swift
//
//
//  Created by Yildirim, Alper on 16.08.2024.
//

import CocoaLumberjack

/// Represents different levels of logging, ordered by severity
public enum LogLevel: Int, Comparable, Equatable, Sendable, CustomStringConvertible {
    case trace = 0
    case debug = 1
    case info = 2
    case warning = 3
    case error = 4
    case critical = 5

    /// Lowercase canonical name of the log level ("trace"/"debug"/.../"critical").
    public var description: String {
        switch self {
        case .trace: return "trace"
        case .debug: return "debug"
        case .info: return "info"
        case .warning: return "warning"
        case .error: return "error"
        case .critical: return "critical"
        }
    }

    /// Convert to CocoaLumberjack log level
    public var ddLogLevel: DDLogLevel {
        switch self {
        case .trace: return .verbose
        case .debug: return .debug
        case .info: return .info
        case .warning: return .warning
        case .error: return .error
        case .critical: return .error
        }
    }

    /// Convert to CocoaLumberjack log flag
    public var flag: DDLogFlag {
        switch self {
        case .trace: return .verbose
        case .debug: return .debug
        case .info: return .info
        case .warning: return .warning
        case .error: return .error
        case .critical: return .error
        }
    }

    /// Convert from CocoaLumberjack log level
    public init(from ddLogLevel: DDLogLevel) {
        switch ddLogLevel {
        case .verbose: self = .trace
        case .debug: self = .debug
        case .info: self = .info
        case .warning: self = .warning
        case .error: self = .error
        default: self = .info
        }
    }

    /// Create a LogLevel from its canonical name (case insensitive).
    public init?(name: String) {
        switch name.lowercased() {
        case "trace": self = .trace
        case "debug": self = .debug
        case "info": self = .info
        case "warning": self = .warning
        case "error": self = .error
        case "critical": self = .critical
        default: return nil
        }
    }

    // Comparable based on severity (Int raw value)
    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
