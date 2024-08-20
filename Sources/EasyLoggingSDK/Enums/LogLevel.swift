//
//  LogLevel.swift
//
//
//  Created by Yildirim, Alper on 16.08.2024.
//

import CocoaLumberjack

public enum LogLevel {
    case debug
    case info
    case warning
    case error
    case verbose

    var ddLogLevel: DDLogLevel {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .warning
        case .error: return .error
        case .verbose: return .verbose
        }
    }

    var flag: DDLogFlag {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .warning
        case .error: return .error
        case .verbose: return .verbose
        }
    }

    var logDescriptionPrefix: String {
        switch self {
        case .debug:
            "[DEBUG]"
        case .info:
            "[INFO]"
        case .warning:
            "*** WARNING ***"
        case .error:
            "!!! ERROR !!!"
        case .verbose:
            "[Verbose]"
        }
    }
}
