//
//  LumberjackLogHandler.swift
//
//
//  Created by Yildirim, Alper on 26.08.2024.
//

import Logging
import CocoaLumberjack

/// A logging backend that writes to CocoaLumberjack
public struct LumberjackLogHandler: Logging.LogHandler {
    private let label: String
    private var _metadata: Logging.Logger.Metadata
    private var _logLevel: Logging.Logger.Level
    
    public init(label: String, minimumLogLevel: LogLevel = .debug) {
        self.label = label
        self._metadata = [:]
        self._logLevel = minimumLogLevel.toSwiftLogLevel()
    }
    
    // MARK: - LogHandler Protocol
    
    public var logLevel: Logging.Logger.Level {
        get { _logLevel }
        set { _logLevel = newValue }
    }
    
    public var metadata: Logging.Logger.Metadata {
        get { _metadata }
        set { _metadata = newValue }
    }
    
    public subscript(metadataKey metadataKey: String) -> Logging.Logger.Metadata.Value? {
        get { _metadata[metadataKey] }
        set { _metadata[metadataKey] = newValue }
    }
    
    public func log(
        level: Logging.Logger.Level,
        message: Logging.Logger.Message,
        metadata: Logging.Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        let combinedMetadata = metadata?.merging(_metadata) { _, new in new } ?? _metadata
        let prettyMetadata = prettify(combinedMetadata)
        let logMessage = "\(message)\(prettyMetadata.map { " \($0)" } ?? "")"
        
        let ddLogLevel = level.toDDLogLevel()
        let flag = level.toDDLogFlag()
        
        // Using va_list since DDLog.log expects a va_list for the arguments
        withVaList([logMessage as NSString]) { args in
            DDLog.log(
                asynchronous: true,
                level: ddLogLevel,
                flag: flag,
                context: 0,
                file: file,
                function: function,
                line: line,
                tag: label,
                format: "%@",
                arguments: args
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func prettify(_ metadata: Logging.Logger.Metadata) -> String? {
        guard !metadata.isEmpty else { return nil }
        return metadata.map { "[\($0):\($1)]" }.joined(separator: " ")
    }
}

// MARK: - Level Conversion Extensions

private extension Logging.Logger.Level {
    func toDDLogLevel() -> DDLogLevel {
        switch self {
        case .trace, .debug: return .debug
        case .info: return .info
        case .notice, .warning: return .warning
        case .error, .critical: return .error
        }
    }
    
    func toDDLogFlag() -> DDLogFlag {
        switch self {
        case .trace, .debug: return .debug
        case .info: return .info
        case .notice, .warning: return .warning
        case .error, .critical: return .error
        }
    }
}

private extension LogLevel {
    func toSwiftLogLevel() -> Logging.Logger.Level {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .warning
        case .error: return .error
        }
    }
}
