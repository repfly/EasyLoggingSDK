// IMPORTANT: plain (non-@testable) import — this file sees ONLY the public API surface, so it
// fails to compile if anything it touches is not actually public. It guards the documented
// surface (e.g. `config.logFormat = .detailed`) against accidental internal access.
import XCTest
import EasyLoggingSDK

final class PublicAPISurfaceCompileTests: XCTestCase {

    func testDocumentedConfigurationSnippetCompiles() {
        // Mirrors the README / DocC "Custom Configuration" example verbatim.
        var config = EasyLogger.Configuration()
        config.minimumLogLevel = .debug
        config.shouldLogToFile = true
        config.logFormat = .detailed
        EasyLogger.shared.configure(config)

        // Every documented preset must be reachable publicly.
        config.logFormat = .default
        config.logFormat = .simple
        config.logFormat = .json
        config.logFormat = .clean
        config.logFormat = LogFormat(template: "%date [%category] %level: %message")

        XCTAssertNotNil(config.logFormat)
    }

    func testDocumentedLoggingSnippetsCompile() {
        let logger = EasyLogger.shared
        logger.trace("t"); logger.debug("d"); logger.info("i")
        logger.warning("w"); logger.error("e"); logger.critical("c")
        logger.info("with metadata", category: "auth", metadata: ["userId": "u_1"])
        logger.info("codable", metadata: LogMetadata(codable: ["k": "v"]))
        XCTAssertEqual(LogLevel.warning.description, "warning")
        XCTAssertEqual(LogLevel(name: "error"), .error)
    }

    func testDocumentedAsyncSnippetsCompile() async {
        let logger = EasyLogger.shared
        await logger.info("async")
        await logger.configure(EasyLogger.Configuration())
        await logger.setEnvironment(.production)
        await logger.flush()
    }
}
