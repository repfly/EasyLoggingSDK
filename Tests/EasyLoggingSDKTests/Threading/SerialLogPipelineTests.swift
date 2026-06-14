import XCTest
@testable import EasyLoggingSDK

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
