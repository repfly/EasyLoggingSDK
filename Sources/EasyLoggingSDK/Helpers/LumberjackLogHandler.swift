//
//  LumberjackLogHandler.swift
//
//
//  Created by Yildirim, Alper on 26.08.2024.
//

import Logging

struct LumberjackLogHandler: LogHandler {
    private let easyLogger: EasyLogger
    var logLevel: Logger.Level = .info
    var metadata: Logger.Metadata = [:]

    init(label: String) {
        self.easyLogger = EasyLogger.shared
    }

    subscript(metadataKey key: String) -> Logger.Metadata.Value? {
        get { return metadata[key] }
        set { metadata[key] = newValue }
    }

    func log(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?, file: String, function: String, line: UInt) {
        let logLevel = LogLevel(from: level)
        let logMessage = "\(message)"
        easyLogger.log(logMessage, level: logLevel, file: file, function: function, line: Int(line))
    }
}

private extension LogLevel {
    init(from swiftLogLevel: Logger.Level) {
        switch swiftLogLevel {
        case .trace: self = .debug
        case .debug: self = .debug
        case .info: self = .info
        case .notice: self = .info
        case .warning: self = .warning
        case .error: self = .error
        case .critical: self = .error
        }
    }
}
