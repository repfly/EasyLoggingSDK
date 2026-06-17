import Foundation

/// A record describing a single log event, captured before crossing the actor boundary.
///
/// Metadata is already redacted by the time it reaches a `LogRecord`.
struct LogRecord: Sendable {
    let messageString: String
    let level: LogLevel
    let category: String?
    let metadata: [String: String]?
    let file: String
    let function: String
    let line: Int
    let config: EasyLogger.Configuration
    /// When `true`, the record is routed through the clean internal-format path.
    let isInternal: Bool
}

/// Work items serialized by ``SerialLogPipeline``.
enum Event: Sendable {
    case record(LogRecord)
    case applyConfiguration(EasyLogger.Configuration)
    /// A one-off operation to run against the logging actor, ordered in FIFO with all other
    /// events. Used for setup work (e.g. wiring the in-app log viewer) that must be observed by
    /// the actor *before* any subsequent log record is processed.
    case actorOperation(@Sendable (LoggingActor) async -> Void)
    case flush(@Sendable () -> Void)
}

/// Serializes all logging work through a single `AsyncStream` consumed by one long-lived task.
///
/// Enqueued events are processed strictly in FIFO order: the consumer awaits each event's
/// handler before pulling the next, so log lines, configuration applies, and flush markers
/// are delivered in the exact order they were enqueued. This is the logger's #1 correctness
/// contract — strict ordering — replacing per-call unstructured `Task`s that had no ordering
/// guarantee.
final class SerialLogPipeline: Sendable {
    private let continuation: AsyncStream<Event>.Continuation

    /// Creates the pipeline and starts its single serial consumer task.
    ///
    /// - Parameter handler: Invoked for every event in enqueue order. The consumer awaits
    ///   each invocation before processing the next event, guaranteeing FIFO ordering.
    init(handler: @escaping @Sendable (Event) async -> Void) {
        // Unbounded buffering is a deliberate choice: a diagnostics logger must not silently
        // drop records, so memory is traded for completeness. Under an extreme log storm the
        // queue can grow until the serial consumer catches up. If bounded memory ever becomes a
        // hard requirement, switch to `.bufferingNewest(_:)` and surface an overflow counter
        // rather than dropping silently.
        let (stream, continuation) = AsyncStream.makeStream(
            of: Event.self,
            bufferingPolicy: .unbounded
        )
        self.continuation = continuation

        Task {
            for await event in stream {
                // Flush is a pipeline-internal concern: the consumer resumes the marker itself
                // so flush() works regardless of what the handler does. Reaching the marker means
                // every prior event has already been awaited, i.e. fully processed.
                if case let .flush(done) = event {
                    done()
                } else {
                    await handler(event)
                }
            }
        }
    }

    /// Enqueues an event for serial processing. Synchronous, non-blocking, and ordered.
    func enqueue(_ event: Event) {
        // `yield` returns a discardable result; a terminated stream is ignored.
        _ = continuation.yield(event)
    }

    /// Awaits until every previously enqueued event has been fully processed.
    ///
    /// Because the consumer is serial, reaching the flush marker means all prior work is done.
    func flush() async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            let result = continuation.yield(.flush({ cont.resume() }))
            // If the stream is already terminated, the flush marker will never be delivered;
            // resume immediately so callers do not hang.
            if case .terminated = result {
                cont.resume()
            }
        }
    }
}
