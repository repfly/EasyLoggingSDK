import Foundation

/// Defines the logging environment for the application.
public enum LogEnvironment: String {
    case development
    case staging
    case production

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
            config.logViewerActivationGesture = .longPress
            config.trackScreenLoadingTimes = true

        case .staging:
            config.minimumLogLevel = .info
            config.shouldLogToConsole = false
            config.shouldLogToFile = true
            config.enableInAppLogViewer = true

        case .production:
            config.minimumLogLevel = .warning
            config.shouldLogToConsole = false
            config.shouldLogToFile = true
        }
        return config
    }
}
