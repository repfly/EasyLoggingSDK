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
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
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
    
    /// Cleans up old log files
    /// - Parameter maxAge: Maximum age of log files in days
    static func cleanOldLogFiles(maxAge: TimeInterval = 7 * 24 * 60 * 60) {
        let fileManager = FileManager.default
        let logDirectory = getLogDirectory()
        let logDirectoryURL = URL(fileURLWithPath: logDirectory)
        
        guard let contents = try? fileManager.contentsOfDirectory(
            at: logDirectoryURL,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        
        let cutoffDate = Date().addingTimeInterval(-maxAge)
        
        contents.forEach { fileURL in
            guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                  let creationDate = attributes[.creationDate] as? Date,
                  creationDate < cutoffDate else { return }
            
            try? fileManager.removeItem(at: fileURL)
        }
    }
    
    /// Returns the total size of log files
    /// - Returns: Total size in bytes
    static func getLogFilesSize() -> UInt64 {
        let fileManager = FileManager.default
        let logDirectory = getLogDirectory()
        let logDirectoryURL = URL(fileURLWithPath: logDirectory)
        
        guard let contents = try? fileManager.contentsOfDirectory(
            at: logDirectoryURL,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        
        return contents.reduce(0) { totalSize, fileURL in
            guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                  let fileSize = attributes[.size] as? UInt64 else { return totalSize }
            return totalSize + fileSize
        }
    }
}
