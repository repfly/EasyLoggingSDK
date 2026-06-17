import XCTest
@testable import EasyLoggingCore

final class SerialLogPipelineTests: XCTestCase {

    /// Collects processed messages in the order the pipeline handler is invoked.
    private actor Collector {
        private(set) var messages: [String] = []
        private(set) var count = 0

        func append(_ message: String) {
            messages.append(message)
            count += 1
        }
    }

    private func makeRecord(_ message: String) -> LogRecord {
        LogRecord(
            messageString: message,
            level: .info,
            category: nil,
            metadata: nil,
            file: "",
            function: "",
            line: 0,
            config: EasyLogger.Configuration(),
            isInternal: false
        )
    }

    func testProcessesEventsInFIFOOrder() async {
        let collector = Collector()
        let pipeline = SerialLogPipeline { event in
            if case let .record(record) = event {
                await collector.append(record.messageString)
            }
        }

        let inputs = (0..<1000).map { String($0) }
        for input in inputs {
            pipeline.enqueue(.record(makeRecord(input)))
        }

        await pipeline.flush()

        let collected = await collector.messages
        XCTAssertEqual(collected, inputs, "Records must be processed in strict FIFO order")
    }

    func testFlushDrainsAllEnqueuedWork() async {
        let collector = Collector()
        let pipeline = SerialLogPipeline { event in
            if case let .record(record) = event {
                await collector.append(record.messageString)
            }
        }

        let count = 500
        for index in 0..<count {
            pipeline.enqueue(.record(makeRecord(String(index))))
        }

        await pipeline.flush()

        let processed = await collector.count
        XCTAssertEqual(processed, count, "Flush must guarantee all enqueued work is processed")
    }

    /// Records and configuration applies must observe the SAME serial FIFO order: a config
    /// enqueued between two records must be applied strictly after the first and before the
    /// second. This pins the ordering contract across event *types*, not just records.
    func testInterleavedRecordsAndConfigurationApplysPreserveOrdering() async {
        // Collects record + config events in the exact order the handler observes them.
        actor Trace {
            private(set) var events: [String] = []
            func record(_ message: String) { events.append("record:\(message)") }
            func config(_ level: LogLevel) { events.append("config:\(level)") }
            var snapshot: [String] { events }
        }
        let trace = Trace()

        let pipeline = SerialLogPipeline { event in
            switch event {
            case let .record(record):
                await trace.record(record.messageString)
            case let .applyConfiguration(configuration):
                await trace.config(configuration.minimumLogLevel)
            case .actorOperation, .flush:
                break
            }
        }

        // Interleave: record A, config(.error), record B, config(.warning), record C.
        pipeline.enqueue(.record(makeRecord("A")))
        var errorConfig = EasyLogger.Configuration()
        errorConfig.minimumLogLevel = .error
        pipeline.enqueue(.applyConfiguration(errorConfig))
        pipeline.enqueue(.record(makeRecord("B")))
        var warningConfig = EasyLogger.Configuration()
        warningConfig.minimumLogLevel = .warning
        pipeline.enqueue(.applyConfiguration(warningConfig))
        pipeline.enqueue(.record(makeRecord("C")))

        await pipeline.flush()

        let observed = await trace.snapshot
        XCTAssertEqual(
            observed,
            [
                "record:A",
                "config:error",
                "record:B",
                "config:warning",
                "record:C"
            ],
            "Config applies must be ordered exactly between the records they were enqueued between"
        )
    }

    func testFlushWithNoWorkReturns() async {
        let pipeline = SerialLogPipeline { _ in }

        let expectation = XCTestExpectation(description: "Flush on idle pipeline returns promptly")
        Task {
            await pipeline.flush()
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 2.0)
    }
}
