//
//  EasyLogFormat.swift
//
//
//  Created by Yildirim, Alper on 16.08.2024.
//
import CocoaLumberjack

enum DateFormat {
    static var `default` = "yyyy-MM-dd HH:mm:ss.SSS"
}

class EasyLogFormat: NSObject, DDLogFormatter {

    let dateFormatter: DateFormatter

    override init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = DateFormat.default
        super.init()
    }

    func format(message logMessage: DDLogMessage) -> String? {
        let timestamp = dateFormatter.string(from: logMessage.timestamp)
        let logLevel = logMessage.level
        let logText = logMessage.message
        return "\(timestamp) [\(logLevel)] - \(logText)"
    }
}
