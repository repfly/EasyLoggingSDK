import EasyLoggingCore
import Foundation

/// Intercepts URLSession requests via `URLProtocol` and logs request/response details.
///
/// This class is **opt-in only** — it never swizzles global state.
/// Use ``EasyLogger/networkLoggingSessionConfiguration(base:)`` to get a pre-configured
/// `URLSessionConfiguration`, or register ``NetworkLoggerURLProtocol`` manually.
///
/// ## Known limitations
/// `URLProtocol`-based interception has inherent constraints:
/// - It does **not** intercept requests issued on background `URLSessionConfiguration`s.
/// - It can interfere with request bodies provided as streams (`httpBodyStream`) and with
///   requests that are re-issued (e.g. redirects), since the body is consumed once.
/// - It only observes requests on sessions explicitly configured with
///   ``NetworkLoggerURLProtocol``; it never sees traffic from other sessions.
///
/// ## Privacy
/// The full URL and any `Authorization`/`Cookie`/`Set-Cookie` header values are captured with
/// ``RedactionLevel/auto``, which only masks them in the `.production` environment. In any
/// non-production build these are written to the log files in plaintext — do **not** ship a
/// non-production logging build to external testers with live credentials.
public actor NetworkLogger {

    // MARK: - Singleton

    public static let shared = NetworkLogger()

    private init() {}

    /// The formatted, redaction-aware result of inspecting a completed request.
    struct LogEntry: Sendable {
        let message: String
        let level: LogLevel
        let metadata: LogMetadata
    }

    // MARK: - Tracking

    /// Formats, redacts, and logs a completed request.
    ///
    /// Timing is measured on the ``NetworkLoggerURLProtocol`` instance and passed in as
    /// `duration`, so the actor holds no shared mutable timing state. Only `Sendable` values
    /// (the request, response, data, error, and a `Double` duration) cross the actor boundary.
    func requestCompleted(
        _ request: URLRequest,
        response: URLResponse?,
        data: Data?,
        error: Error?,
        duration: TimeInterval
    ) {
        let entry = Self.makeLogEntry(
            request: request,
            response: response,
            data: data,
            error: error,
            duration: duration
        )
        EasyLogger.shared.log(
            entry.message,
            level: entry.level,
            category: "network",
            metadata: entry.metadata
        )

        guard EasyLogger.shared.configuration.enableInAppLogViewer else { return }
        let record = Self.makeNetworkRecord(
            request: request,
            response: response,
            data: data,
            error: error,
            duration: duration,
            isProduction: EasyLogger.shared.environment == .production,
            maxBodyBytes: LoggingConstants.Defaults.maxNetworkBodyBytes
        )
        NetworkActivityStore.shared.record(record)
    }

    private static let sensitiveHeaderKeys: Set<String> = [
        "authorization", "cookie", "set-cookie", "proxy-authorization", "x-api-key"
    ]

    /// Pure builder for a ``NetworkRequestRecord``. In `.production`, sensitive headers are redacted
    /// and bodies omitted; otherwise bodies are captured truncated to `maxBodyBytes`.
    static func makeNetworkRecord(
        request: URLRequest,
        response: URLResponse?,
        data: Data?,
        error: Error?,
        duration: TimeInterval,
        isProduction: Bool,
        maxBodyBytes: Int
    ) -> NetworkRequestRecord {
        let httpResponse = response as? HTTPURLResponse
        let url = request.url

        let requestHeaders = redactHeaders(request.allHTTPHeaderFields ?? [:], isProduction: isProduction)
        let responseHeaders = redactHeaders(stringHeaders(httpResponse?.allHeaderFields), isProduction: isProduction)

        return NetworkRequestRecord(
            id: UUID(),
            date: Date(),
            method: request.httpMethod ?? "GET",
            url: url?.absoluteString ?? "unknown",
            host: url?.host,
            path: url?.path ?? "",
            statusCode: httpResponse?.statusCode,
            duration: duration,
            requestHeaders: requestHeaders,
            requestBody: capturedBody(request.httpBody, isProduction: isProduction, maxBodyBytes: maxBodyBytes),
            responseHeaders: responseHeaders,
            responseBody: capturedBody(data, isProduction: isProduction, maxBodyBytes: maxBodyBytes),
            errorMessage: error?.localizedDescription,
            requestSize: request.httpBody?.count ?? 0,
            responseSize: data?.count ?? 0
        )
    }

    private static func redactHeaders(_ headers: [String: String], isProduction: Bool) -> [String: String] {
        guard isProduction else { return headers }
        var result: [String: String] = [:]
        for (key, value) in headers {
            result[key] = sensitiveHeaderKeys.contains(key.lowercased()) ? "<REDACTED>" : value
        }
        return result
    }

    private static func stringHeaders(_ headers: [AnyHashable: Any]?) -> [String: String] {
        guard let headers else { return [:] }
        var result: [String: String] = [:]
        for (key, value) in headers {
            result["\(key)"] = "\(value)"
        }
        return result
    }

    private static func capturedBody(_ body: Data?, isProduction: Bool, maxBodyBytes: Int) -> Data? {
        guard !isProduction, let body, !body.isEmpty else { return nil }
        return body.count > maxBodyBytes ? Data(body.prefix(maxBodyBytes)) : body
    }

    /// Builds the `(message, level, metadata)` for a completed request.
    ///
    /// Pure and side-effect-free so it can be unit-tested directly. The message is the
    /// never-redacted, query-stripped form; the full URL lives only in redactable metadata.
    static func makeLogEntry(
        request: URLRequest,
        response: URLResponse?,
        data: Data?,
        error: Error?,
        duration: TimeInterval
    ) -> LogEntry {
        let httpResponse = response as? HTTPURLResponse

        let method = request.httpMethod ?? "GET"
        let url = request.url?.absoluteString ?? "unknown"
        // Query/fragment can carry tokens — strip them for the (never-redacted) message string.
        // The full URL is kept only in the redactable `url` metadata below.
        let safeURL: String = {
            guard let requestURL = request.url,
                  var components = URLComponents(url: requestURL, resolvingAgainstBaseURL: false) else {
                return request.url?.path ?? "unknown"
            }
            components.query = nil
            components.fragment = nil
            return components.string ?? requestURL.path
        }()
        let statusCode = httpResponse?.statusCode ?? 0
        // Raw byte counts for machine-parseable diagnostics. Request size comes from the
        // original request body; response size from the received data.
        let requestSize = request.httpBody?.count ?? 0
        let responseSize = data?.count ?? 0

        var metadata: LogMetadata = [
            "method": method,
            "status_code": statusCode,
            "duration_ms": String(format: "%.1f", duration * 1000),
            "request_size": requestSize as Int,
            "response_size": responseSize as Int
        ]

        // The full URL may carry query tokens; redact in production.
        metadata.setRedactable(url, forKey: "url", redaction: .auto)

        // Capture sensitive auth headers from the request as redactable when present.
        for headerKey in ["Authorization", "Cookie"] {
            if let value = request.value(forHTTPHeaderField: headerKey) {
                metadata.setRedactable(value, forKey: headerKey.lowercased(), redaction: .auto)
            }
        }
        // Set-Cookie is a response header.
        if let setCookie = httpResponse?.value(forHTTPHeaderField: "Set-Cookie") {
            metadata.setRedactable(setCookie, forKey: "set-cookie", redaction: .auto)
        }

        if let error = error {
            metadata["error"] = error.localizedDescription
        }

        let level: LogLevel
        let message: String

        if let error = error {
            level = .error
            message = "\(method) \(safeURL) failed — \(error.localizedDescription)"
        } else if statusCode >= 400 {
            level = .warning
            message = "\(method) \(safeURL) → \(statusCode) (\(String(format: "%.0fms", duration * 1000)))"
        } else {
            level = .debug
            message = "\(method) \(safeURL) → \(statusCode) (\(String(format: "%.0fms", duration * 1000)))"
        }

        return LogEntry(message: message, level: level, metadata: metadata)
    }
}

// MARK: - URLProtocol

/// A `URLProtocol` subclass that intercepts network requests for logging.
///
/// Registered automatically when you use ``EasyLogger/networkLoggingSessionConfiguration(base:)``.
/// You can also register it manually on any `URLSessionConfiguration`.
///
/// ## Known limitations
/// As a `URLProtocol`, this class does **not** intercept background `URLSessionConfiguration`s,
/// can interfere with request bodies provided as streams (`httpBodyStream`) and re-issued
/// requests (the body is consumed once), and only sees requests on sessions configured with this
/// protocol.
///
/// This is intentionally **not** `Sendable`: a `URLProtocol` subclass is created and driven by
/// `URLSession` on its own serialized context. Its mutable stored state (`dataTask`,
/// `internalSession`, `startTime`) is only ever touched from `URLProtocol`'s own start/stop
/// callbacks and the internal session's delegate callbacks, which `URLSession` serializes. To
/// avoid inheriting a `Sendable` requirement from `URLSessionDataDelegate` (whose ancestor
/// `URLSessionDelegate` is `Sendable`), the delegate work is delegated to a separate
/// `SessionDelegate` object rather than conforming `self`.
public final class NetworkLoggerURLProtocol: URLProtocol {

    private var dataTask: URLSessionDataTask?
    private let sessionDelegate = SessionDelegate()
    /// Captured when `startLoading` begins; the request duration is computed against this on the
    /// instance itself, so the logging actor never needs to track per-request start times.
    private var startTime: CFAbsoluteTime = 0
    private lazy var internalSession: URLSession = {
        let config = URLSessionConfiguration.default
        return URLSession(configuration: config, delegate: sessionDelegate, delegateQueue: nil)
    }()

    // MARK: - URLProtocol overrides

    // `URLProtocol` requires these as `override class func`, so `static_over_final_class` is a false positive.
    // swiftlint:disable:next static_over_final_class
    override public class func canInit(with request: URLRequest) -> Bool {
        guard URLProtocol.property(forKey: Constants.handledKey, in: request) == nil else {
            return false
        }
        return true
    }

    // swiftlint:disable:next static_over_final_class
    override public class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override public func startLoading() {
        guard let mutableRequest = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            // Practically unreachable, but never leave the request hanging: tell the client it
            // failed rather than returning silently (which would emit no start/finish).
            let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorUnknown)
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        URLProtocol.setProperty(true, forKey: Constants.handledKey, in: mutableRequest)

        // Start the clock on the instance — no shared timing state in the actor.
        startTime = CFAbsoluteTimeGetCurrent()

        // Wire the delegate back to this protocol instance so it can forward to `client`.
        sessionDelegate.owner = self
        dataTask = internalSession.dataTask(with: mutableRequest as URLRequest)
        dataTask?.resume()
    }

    override public func stopLoading() {
        dataTask?.cancel()
        // URLSession strongly retains its delegate until invalidated. Invalidate so the internal
        // session and its delegate are released.
        internalSession.invalidateAndCancel()
    }

    // MARK: - Client forwarding (called by SessionDelegate on the session's context)

    fileprivate func didReceiveResponse(_ response: URLResponse) {
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    }

    fileprivate func didReceiveData(_ data: Data) {
        client?.urlProtocol(self, didLoad: data)
    }

    fileprivate func didComplete(request: URLRequest, response: URLResponse?, data: Data, error: Error?) {
        // Compute the duration on the instance; only Sendable values (including the Double
        // duration) cross the actor boundary into the logging actor.
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        Task {
            await NetworkLogger.shared.requestCompleted(
                request,
                response: response,
                data: data,
                error: error,
                duration: duration
            )
        }

        if let error = error {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            client?.urlProtocolDidFinishLoading(self)
        }

        // Release the internal session and its delegate now that the request is finished.
        // `finishTasksAndInvalidate` lets the (already complete) task drain cleanly.
        internalSession.finishTasksAndInvalidate()
    }

    private enum Constants {
        static let handledKey = "dev.alpr.EasyLoggingSDK.NetworkLoggerHandled"
    }
}

// MARK: - URLSessionDataDelegate

/// Receives the internal `URLSession`'s delegate callbacks and forwards them to the owning
/// ``NetworkLoggerURLProtocol``.
///
/// This is its own `NSObject` subclass (not the `URLProtocol`) so that conforming to the
/// `Sendable`-refined `URLSessionDataDelegate` protocol does not impose a `Sendable` requirement
/// on the non-`Sendable` `URLProtocol` subclass. All callbacks arrive on the session's
/// serialized delegate context; `receivedData` and `owner` are only mutated there.
private final class SessionDelegate: NSObject, URLSessionDataDelegate {
    // `URLSessionDataDelegate` refines the `Sendable` `URLSessionDelegate`, so this class is
    // required to conform to `Sendable`. Its mutable state is hand-synchronized: `owner` is set
    // once on the session's context before the task starts, and both `owner` and `receivedData`
    // are read/mutated only from the session's serialized delegate callbacks — never concurrently.
    // `nonisolated(unsafe)` documents that manual synchronization to the compiler.
    nonisolated(unsafe) weak var owner: NetworkLoggerURLProtocol?
    nonisolated(unsafe) private var receivedData = Data()

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        owner?.didReceiveResponse(response)
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        receivedData.append(data)
        owner?.didReceiveData(data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let owner = owner else { return }
        owner.didComplete(
            request: owner.request,
            response: task.response,
            data: receivedData,
            error: error
        )
    }
}
