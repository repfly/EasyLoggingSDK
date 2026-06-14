import Foundation

@available(iOS 15.0, macOS 12.0, *)
public extension EasyLogger {
    /// Asynchronously rotates the current log file
    func rotateLogFileAsync() async {
        await loggingActor.rotateLogFile()
    }

    /// Asynchronously removes all log files
    func removeAllLogFilesAsync() async {
        await loggingActor.removeAllLogFiles()
    }

    /// Asynchronously logs a message with the specified level and metadata
    func logAsync(
        _ message: @autoclosure () -> String,
        level: LogLevel = .info,
        category: String? = nil,
        metadata: LogMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) async {
        let config = self.configuration
        guard level >= config.minimumLogLevel else { return }

        let evaluatedMessage = message()
        let redacted: [String: String]? = metadata?.redactedDictionary(isProduction: self.environment == .production)
        await loggingActor.log(
            messageString: evaluatedMessage,
            level: level,
            category: category,
            metadata: redacted,
            file: file,
            function: function,
            line: line,
            config: config
        )
    }

    /// Asynchronously logs a debug message
    func debugAsync(
        _ message: @autoclosure () -> String,
        category: String? = nil,
        metadata: LogMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) async {
        await logAsync(
            message(),
            level: .debug,
            category: category,
            metadata: metadata,
            file: file,
            function: function,
            line: line
        )
    }

    /// Asynchronously logs an info message
    func infoAsync(
        _ message: @autoclosure () -> String,
        category: String? = nil,
        metadata: LogMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) async {
        await logAsync(
            message(),
            level: .info,
            category: category,
            metadata: metadata,
            file: file,
            function: function,
            line: line
        )
    }

    /// Asynchronously logs a warning message
    func warningAsync(
        _ message: @autoclosure () -> String,
        category: String? = nil,
        metadata: LogMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) async {
        await logAsync(
            message(),
            level: .warning,
            category: category,
            metadata: metadata,
            file: file,
            function: function,
            line: line
        )
    }

    /// Asynchronously logs an error message
    func errorAsync(
        _ message: @autoclosure () -> String,
        category: String? = nil,
        metadata: LogMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) async {
        await logAsync(
            message(),
            level: .error,
            category: category,
            metadata: metadata,
            file: file,
            function: function,
            line: line
        )
    }

    /// Asynchronously configures the logger
    func configureAsync(_ configuration: Configuration) async {
        _lock.withLock { self._configuration = configuration }
        await loggingActor.applyConfiguration(configuration)
    }

    /// Asynchronously sets up the environment
    func setupEnvironmentAsync(
        _ environment: LogEnvironment,
        customConfiguration: Configuration? = nil
    ) async {
        _lock.withLock { self._currentEnvironment = environment }
        UserDefaults.standard.set(environment.rawValue, forKey: self.environmentKey)

        let config = customConfiguration ?? environment.defaultConfiguration
        _lock.withLock { self._configuration = config }
        await loggingActor.applyConfiguration(config)
    }
}
