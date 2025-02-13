//
//  Environment.swift
//
//
//  Created by Yildirim, Alper on 12.02.2025.
//

import Foundation

/// Represents different environments for logging configuration
public enum Environment: String {
    /// Development environment with verbose logging
    case development
    /// Staging environment with moderate logging
    case staging
    /// Production environment with minimal logging
    case production
    /// Custom environment with user-defined settings
    case custom
    
    /// Default configuration for each environment
    var defaultConfiguration: EasyLogger.Configuration {
        switch self {
        case .development:
            var config = EasyLogger.Configuration()
            config.minimumLogLevel = .debug
            config.shouldLogToConsole = true
            config.shouldLogToFile = true
            config.shouldDetectCrashes = true
            config.enableShakeToShare = true
            config.trackScreenLoadingTimes = true
            config.slowScreenLoadingThreshold = 0.5
            config.maxFileSize = 10_000_000 // 10MB
            config.maxLogFiles = 10
            config.logFormat = .detailed
            config.enableMemoryLeakDetection = true
            config.memoryLeakCheckInterval = 5.0
            return config
            
        case .staging:
            var config = EasyLogger.Configuration()
            config.minimumLogLevel = .info
            config.shouldLogToConsole = true
            config.shouldLogToFile = true
            config.shouldDetectCrashes = true
            config.enableShakeToShare = true
            config.trackScreenLoadingTimes = true
            config.slowScreenLoadingThreshold = 1.0
            config.maxFileSize = 5_000_000 // 5MB
            config.maxLogFiles = 7
            config.logFormat = .default
            config.enableMemoryLeakDetection = true
            config.memoryLeakCheckInterval = 10.0
            return config
            
        case .production:
            var config = EasyLogger.Configuration()
            config.minimumLogLevel = .warning
            config.shouldLogToConsole = false
            config.shouldLogToFile = true
            config.shouldDetectCrashes = true
            config.enableShakeToShare = false
            config.trackScreenLoadingTimes = true
            config.slowScreenLoadingThreshold = 2.0
            config.maxFileSize = 2_000_000 // 2MB
            config.maxLogFiles = 5
            config.logFormat = .simple
            config.enableMemoryLeakDetection = false
            return config
            
        case .custom:
            return EasyLogger.Configuration()
        }
    }
} 
