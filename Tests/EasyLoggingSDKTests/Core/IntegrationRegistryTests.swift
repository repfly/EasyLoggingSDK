import XCTest
@testable import EasyLoggingCore

final class IntegrationRegistryTests: XCTestCase {

    private final class StubIntegration: EasyLoggerIntegration, @unchecked Sendable {
        private let lock = NSLock()
        private var applied: [(previous: EasyLogger.Configuration?, new: EasyLogger.Configuration)] = []

        var calls: [(previous: EasyLogger.Configuration?, new: EasyLogger.Configuration)] {
            lock.lock(); defer { lock.unlock() }
            return applied
        }

        func apply(previous: EasyLogger.Configuration?, new: EasyLogger.Configuration) {
            lock.lock(); applied.append((previous, new)); lock.unlock()
        }
    }

    private final class StubSink: LogSink, @unchecked Sendable {
        private let lock = NSLock()
        private var messages: [String] = []

        var received: [String] {
            lock.lock(); defer { lock.unlock() }
            return messages
        }

        func addLogEntry(message: String, level: LogLevel, category: String?, metadata: [String: String]?) {
            lock.lock(); messages.append(message); lock.unlock()
        }
    }

    func testRegisterReplaysCurrentConfigThenForwardsChanges() {
        let logger = EasyLogger.shared
        let stub = StubIntegration()

        logger.register(stub)
        XCTAssertEqual(stub.calls.count, 1, "registration replays the current config once")
        XCTAssertNil(stub.calls[0].previous, "initial replay has no previous config")

        var config = EasyLogger.Configuration()
        config.minimumLogLevel = .warning
        logger.configure(config)

        XCTAssertEqual(stub.calls.count, 2)
        XCTAssertNotNil(stub.calls[1].previous)
        XCTAssertEqual(stub.calls[1].new.minimumLogLevel, .warning)
    }

    func testRegisteringSameIntegrationTwiceIsNoOp() {
        let logger = EasyLogger.shared
        let stub = StubIntegration()

        logger.register(stub)
        logger.register(stub)
        XCTAssertEqual(stub.calls.count, 1, "re-registration must not replay again")

        var config = EasyLogger.Configuration()
        config.minimumLogLevel = .error
        logger.configure(config)

        XCTAssertEqual(stub.calls.count, 2, "a duplicate registration must not double-deliver changes")
    }

    func testRegisteredLogSinkReceivesRecordsWhenViewerEnabled() async {
        let logger = EasyLogger.shared
        var config = EasyLogger.Configuration()
        config.enableInAppLogViewer = true
        config.minimumLogLevel = .trace
        await logger.configure(config)

        let sink = StubSink()
        logger.registerLogSink(sink)
        await logger.log("decoupled sink entry", level: .info)
        await logger.flush()

        XCTAssertTrue(sink.received.contains("decoupled sink entry"))
    }
}
