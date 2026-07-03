import Foundation

/// Constants used throughout the EasyLoggingSDK
public enum LoggingConstants {
    /// Queue identifiers
    public enum QueueIdentifier {
        /// Main logging queue identifier
        public static let main = "dev.alpr.EasyLoggingSDK"
        /// Screen tracker queue identifier
        public static let screenTracker = "dev.alpr.EasyLoggingSDK.screentracker"
    }
    
    /// UserDefaults keys
    public enum UserDefaultsKey {
        /// Key for environment setting
        public static let environment = "dev.alpr.EasyLoggingSDK.environment"
    }
    
    /// File system related constants
    public enum FileSystem {
        /// Default directory for logs
        public static let defaultLogDirectory = "EasyLoggingSDK/Logs"
    }
    
    /// File management log messages
    public enum FileManagementMessage {
        public static let rotationSuccess = "Log file rotated successfully"
        public static let removalSuccess = "All log files have been removed"
        public static let removalError = "Failed to remove log files: %@"
    }

    /// Metadata keys
    public enum MetadataKey {
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
        /// Default maximum number of network requests retained by the in-app inspector
        public static let maxNetworkViewerEntries: Int = 500
        /// Maximum captured request/response body size (512 KB); larger bodies are truncated
        public static let maxNetworkBodyBytes: Int = 512 * 1024
    }
} 
