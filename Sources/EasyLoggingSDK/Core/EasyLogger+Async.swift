import Foundation

@available(iOS 15.0, macOS 12.0, *)
public extension EasyLogger {
    /// Asynchronously rotates the current log file.
    func rotateLogFile() async {
        await loggingActor.rotateLogFile()
    }

    /// Asynchronously removes all log files.
    func removeAllLogFiles() async {
        await loggingActor.removeAllLogFiles()
    }

    /// Asynchronously logs a message with the specified level and metadata.
    ///
    /// Keeps the Phase-2 semantics: the record is enqueued through the pipeline (preserving FIFO
    /// ordering relative to sync logs and config applies), then `flush()` is awaited so the line is
    /// delivered before this call returns.
    func log(
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
        pipeline.enqueue(.record(record))
        await pipeline.flush()
    }

    /// Asynchronously logs a trace message.
    func trace(
        _ message: @autoclosure () -> String,
        category: String? = nil,
        metadata: LogMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) async {
        await log(message(), level: .trace, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    /// Asynchronously logs a debug message.
    func debug(
        _ message: @autoclosure () -> String,
        category: String? = nil,
        metadata: LogMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) async {
        await log(message(), level: .debug, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    /// Asynchronously logs an info message.
    func info(
        _ message: @autoclosure () -> String,
        category: String? = nil,
        metadata: LogMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) async {
        await log(message(), level: .info, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    /// Asynchronously logs a warning message.
    func warning(
        _ message: @autoclosure () -> String,
        category: String? = nil,
        metadata: LogMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) async {
        await log(message(), level: .warning, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    /// Asynchronously logs an error message.
    func error(
        _ message: @autoclosure () -> String,
        category: String? = nil,
        metadata: LogMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) async {
        await log(message(), level: .error, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    /// Asynchronously logs a critical message.
    func critical(
        _ message: @autoclosure () -> String,
        category: String? = nil,
        metadata: LogMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) async {
        await log(message(), level: .critical, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    /// Asynchronously applies a configuration, awaiting until it is fully applied.
    func configure(_ configuration: Configuration) async {
        applyConfigurationChange(configuration)
        await pipeline.flush()
    }

    /// Asynchronously selects an environment preset, awaiting until its configuration is applied.
    func setEnvironment(
        _ environment: LogEnvironment,
        configuration: Configuration? = nil
    ) async {
        _lock.withLock { self._currentEnvironment = environment }
        UserDefaults.standard.set(environment.rawValue, forKey: self.environmentKey)
        applyConfigurationChange(configuration ?? environment.defaultConfiguration)
        await pipeline.flush()
    }
}
