//
//  LogLevel.swift
//
//
//  Created by Yildirim, Alper on 16.08.2024.
//

import CocoaLumberjack

/// Represents different levels of logging
public enum LogLevel: Int, Comparable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3
    
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
    
    // Implement Comparable
    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
