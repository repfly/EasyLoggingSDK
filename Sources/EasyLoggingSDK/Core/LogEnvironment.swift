import Foundation

/// Defines the logging environment for the application.
public enum LogEnvironment: String {
    case development
    case staging
    case production
    case custom

    /// Provides a default configuration for each environment.
    public var defaultConfiguration: EasyLogger.Configuration {
        var config = EasyLogger.Configuration()

        switch self {
        case .development:
            config.minimumLogLevel = .debug
            config.shouldLogToConsole = true
            config.shouldLogToFile = true
            config.enableShakeToShare = true
            config.enableInAppLogViewer = true
            config.enableMemoryLeakDetection = true
            config.trackScreenLoadingTimes = true

        case .staging:
            config.minimumLogLevel = .info
            config.shouldLogToConsole = false
            config.shouldLogToFile = true
            config.enableInAppLogViewer = true
            config.logViewerAccessCode = "qa_access"

        case .production:
            config.minimumLogLevel = .warning
            config.shouldLogToConsole = false
            config.shouldLogToFile = true
            config.shouldDetectCrashes = true

        case .custom:
            // For custom, we start with production-like settings.
            // The user is expected to override this entirely.
            config.minimumLogLevel = .info
            config.shouldLogToFile = true
        }
        return config
    }
}
