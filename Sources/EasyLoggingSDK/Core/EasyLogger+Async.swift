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
        let record = LogRecord(
            messageString: evaluatedMessage,
            level: level,
            category: category,
            metadata: redacted,
            file: file,
            function: function,
            line: line,
            config: config,
            isInternal: false
        )
        // Enqueue through the pipeline (preserving FIFO ordering relative to sync logs and
        // config applies), then flush so the line is delivered before this call returns.
        pipeline.enqueue(.record(record))
        await pipeline.flush()
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
        pipeline.enqueue(.applyConfiguration(configuration))
        await pipeline.flush()
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
        pipeline.enqueue(.applyConfiguration(config))
        await pipeline.flush()
    }
}
