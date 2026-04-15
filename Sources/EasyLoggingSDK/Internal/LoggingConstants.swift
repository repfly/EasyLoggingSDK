//
//  LoggingConstants.swift
//
//
//  Created by Yildirim, Alper on 12.02.2025.
//

import Foundation

/// Constants used throughout the EasyLoggingSDK
public enum LoggingConstants {
    /// Queue identifiers
    public enum QueueIdentifier {
        /// Main logging queue identifier
        public static let main = "dev.alpr.EasyLoggingSDK"
        /// Screen tracker queue identifier
        public static let screenTracker = "dev.alpr.EasyLoggingSDK.screentracker"
        /// Memory leak detector queue identifier
        public static let memoryLeakDetector = "dev.alpr.EasyLoggingSDK.memoryleak"
    }
    
    /// UserDefaults keys
    public enum UserDefaultsKey {
        /// Key for crash flag
        public static let crashFlag = "dev.alpr.EasyLoggingSDK.crashFlag"
        /// Key for environment setting
        public static let environment = "dev.alpr.EasyLoggingSDK.environment"
    }
    
    /// File system related constants
    public enum FileSystem {
        /// Default directory for logs
        public static let defaultLogDirectory = "EasyLoggingSDK/Logs"
    }
    
    /// Time intervals
    public enum TimeInterval {
        /// Default interval for memory leak checks (5 seconds)
        public static let defaultLeakCheckInterval: Foundation.TimeInterval = 5.0
        /// Time to wait before considering a view controller leaked (30 seconds)
        public static let viewControllerLeakThreshold: Foundation.TimeInterval = 30.0
        /// Time to wait before considering an object leaked (60 seconds)
        public static let objectLeakThreshold: Foundation.TimeInterval = 60.0
        /// Minimum time between leak warnings (60 seconds)
        public static let leakWarningInterval: Foundation.TimeInterval = 60.0
    }
    
    /// Memory leak log messages
    public enum MemoryLeakMessage {
        public static let started = "Started monitoring object for memory leaks"
        public static let detected = "Potential memory leak detected"
        public static let multipleDetected = "Memory leaks detected. Consider investigating retain cycles."
        public static let viewControllerDetails = "View Controller details"
    }

    /// File management log messages
    public enum FileManagementMessage {
        public static let rotationSuccess = "Log file rotated successfully"
        public static let removalSuccess = "All log files have been removed"
        public static let removalError = "Failed to remove log files: %@"
    }

    /// Crash detection log messages
    public enum CrashDetectionMessage {
        public static let crashDetected = """
            🚨 CRASH DETECTED 🚨
            Exception: %@
            Reason: %@
            Stack Trace:
            %@
            """
        public static let previousCrash = "⚠️ App crashed in the previous session"
    }
    
    /// Metadata keys
    public enum MetadataKey {
        public static let objectType = "object_type"
        public static let address = "address"
        public static let lifetime = "lifetime"
        public static let memoryAddress = "memory_address"
        public static let parent = "parent"
        public static let presenting = "presenting"
        public static let presented = "presented"
        public static let hasWindow = "has_window"
        public static let screen = "screen"
        public static let duration = "duration"
        public static let trackingMethod = "tracking_method"
    }
    
    /// Default values
    public enum Defaults {
        /// Default share dialog title
        public static let shareDialogTitle = "Share Logs"
        /// Default share dialog message
        public static let shareDialogMessage = "Would you like to share the log files?"
        /// Default maximum file size (5MB)
        public static let maxFileSize: UInt64 = 5_000_000
        /// Default maximum number of log files
        public static let maxLogFiles: UInt = 7
        /// Default slow screen loading threshold (1.0 seconds)
        public static let slowScreenLoadingThreshold: Foundation.TimeInterval = 1.0
    }
} 
