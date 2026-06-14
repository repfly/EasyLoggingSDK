//
//  DirectoryHelper.swift
//
//
//  Created by Yildirim, Alper on 19.08.2024.
//

import Foundation

/// Helper class for managing log directories
enum DirectoryHelper {
    /// Returns the directory path for storing log files
    /// - Returns: The path to the log directory
    static func getLogDirectory() -> String {
        let fileManager = FileManager.default
        guard let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return NSTemporaryDirectory()
        }
        var logDirectory = cachesDirectory.appendingPathComponent(LoggingConstants.FileSystem.defaultLogDirectory)
        
        do {
            if !fileManager.fileExists(atPath: logDirectory.path) {
                try fileManager.createDirectory(
                    at: logDirectory,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            }
            
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try logDirectory.setResourceValues(resourceValues)
            
            return logDirectory.path
        } catch {
            let tempDirectory = NSTemporaryDirectory()
            let fallbackPath = (tempDirectory as NSString).appendingPathComponent(LoggingConstants.FileSystem.defaultLogDirectory)
            
            try? fileManager.createDirectory(
                atPath: fallbackPath,
                withIntermediateDirectories: true,
                attributes: nil
            )
            
            return fallbackPath
        }
    }
}
