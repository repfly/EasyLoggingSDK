import Foundation

/// Intercepts URLSession requests via `URLProtocol` and logs request/response details.
///
/// This class is **opt-in only** — it never swizzles global state.
/// Use ``EasyLogger/networkLoggingSessionConfiguration()`` to get a pre-configured
/// `URLSessionConfiguration`, or register ``NetworkLoggerURLProtocol`` manually.
public actor NetworkLogger {

    // MARK: - Singleton

    public static let shared = NetworkLogger()

    // MARK: - Properties

    private var pendingRequests: [URLRequest: CFAbsoluteTime] = [:]

    private init() {}

    // MARK: - Tracking

    func requestStarted(_ request: URLRequest) {
        pendingRequests[request] = CFAbsoluteTimeGetCurrent()
    }

    func requestCompleted(_ request: URLRequest, response: URLResponse?, data: Data?, error: Error?) {
        let endTime = CFAbsoluteTimeGetCurrent()
        let startTime = pendingRequests.removeValue(forKey: request)

        let duration = startTime.map { endTime - $0 } ?? 0
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
        let requestSize = request.httpBody?.count ?? 0
        let responseSize = data?.count ?? 0

        var metadata: LogMetadata = [
            "method": method,
            "status_code": statusCode,
            "duration_ms": String(format: "%.1f", duration * 1000),
            "request_size": ByteCountFormatter.string(fromByteCount: Int64(requestSize), countStyle: .memory),
            "response_size": ByteCountFormatter.string(fromByteCount: Int64(responseSize), countStyle: .memory)
        ]

        // The full URL may carry query tokens; redact in production.
        metadata.setRedactable(url, forKey: "url", redaction: .auto)

        // Capture sensitive auth headers as redactable when present.
        for headerKey in ["Authorization", "Cookie", "Set-Cookie"] {
            if let value = request.value(forHTTPHeaderField: headerKey) {
                metadata.setRedactable(value, forKey: headerKey.lowercased(), redaction: .auto)
            }
        }
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

        EasyLogger.shared.log(message, level: level, category: "network", metadata: metadata)
    }
}

// MARK: - URLProtocol

/// A `URLProtocol` subclass that intercepts network requests for logging.
///
/// Registered automatically when you use ``EasyLogger/networkLoggingSessionConfiguration()``.
/// You can also register it manually on any `URLSessionConfiguration`.
public final class NetworkLoggerURLProtocol: URLProtocol {

    private var dataTask: URLSessionDataTask?
    private var receivedData = Data()
    private lazy var internalSession: URLSession = {
        let config = URLSessionConfiguration.default
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    // MARK: - URLProtocol overrides

    override public class func canInit(with request: URLRequest) -> Bool {
        guard URLProtocol.property(forKey: Constants.handledKey, in: request) == nil else {
            return false
        }
        return true
    }

    override public class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override public func startLoading() {
        guard let mutableRequest = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            return
        }
        URLProtocol.setProperty(true, forKey: Constants.handledKey, in: mutableRequest)

        Task { await NetworkLogger.shared.requestStarted(request) }

        dataTask = internalSession.dataTask(with: mutableRequest as URLRequest)
        dataTask?.resume()
    }

    override public func stopLoading() {
        dataTask?.cancel()
    }

    private enum Constants {
        static let handledKey = "dev.alpr.EasyLoggingSDK.NetworkLoggerHandled"
    }
}

// MARK: - URLSessionDataDelegate

extension NetworkLoggerURLProtocol: URLSessionDataDelegate {
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        completionHandler(.allow)
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        receivedData.append(data)
        client?.urlProtocol(self, didLoad: data)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let capturedRequest = request
        let capturedData = receivedData
        let capturedResponse = task.response

        Task {
            await NetworkLogger.shared.requestCompleted(
                capturedRequest,
                response: capturedResponse,
                data: capturedData,
                error: error
            )
        }

        if let error = error {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            client?.urlProtocolDidFinishLoading(self)
        }
    }
}
