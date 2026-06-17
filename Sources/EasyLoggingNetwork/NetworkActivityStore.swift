import EasyLoggingCore
import Foundation

/// A single intercepted network request, captured for the in-app network inspector.
public struct NetworkRequestRecord: Sendable, Identifiable {
    public let id: UUID
    public let date: Date
    public let method: String
    public let url: String
    public let host: String?
    public let path: String
    public let statusCode: Int?
    public let duration: TimeInterval
    public let requestHeaders: [String: String]
    public let requestBody: Data?
    public let responseHeaders: [String: String]
    public let responseBody: Data?
    public let errorMessage: String?
    public let requestSize: Int
    public let responseSize: Int

    public init(
        id: UUID,
        date: Date,
        method: String,
        url: String,
        host: String?,
        path: String,
        statusCode: Int?,
        duration: TimeInterval,
        requestHeaders: [String: String],
        requestBody: Data?,
        responseHeaders: [String: String],
        responseBody: Data?,
        errorMessage: String?,
        requestSize: Int,
        responseSize: Int
    ) {
        self.id = id
        self.date = date
        self.method = method
        self.url = url
        self.host = host
        self.path = path
        self.statusCode = statusCode
        self.duration = duration
        self.requestHeaders = requestHeaders
        self.requestBody = requestBody
        self.responseHeaders = responseHeaders
        self.responseBody = responseBody
        self.errorMessage = errorMessage
        self.requestSize = requestSize
        self.responseSize = responseSize
    }

    public var isFailure: Bool {
        errorMessage != nil || (statusCode ?? 0) >= 400
    }

    public var statusText: String {
        if let statusCode { return String(statusCode) }
        return errorMessage == nil ? "—" : "Error"
    }

    /// A `curl` command that reproduces the request, using the (already-redacted) captured headers.
    public var curlCommand: String {
        var parts = ["curl -X \(method) '\(url)'"]
        for key in requestHeaders.keys.sorted() {
            let value = requestHeaders[key] ?? ""
            parts.append("-H '\(key): \(value)'")
        }
        if let requestBody, let body = String(data: requestBody, encoding: .utf8), !body.isEmpty {
            let escaped = body.replacingOccurrences(of: "'", with: "'\\''")
            parts.append("--data '\(escaped)'")
        }
        return parts.joined(separator: " \\\n  ")
    }

    public var prettyRequestBody: String? { Self.prettyBody(requestBody) }

    public var prettyResponseBody: String? { Self.prettyBody(responseBody) }

    static func prettyBody(_ data: Data?) -> String? {
        guard let data, !data.isEmpty else { return nil }
        if let object = try? JSONSerialization.jsonObject(with: data),
           let pretty = try? JSONSerialization.data(
               withJSONObject: object,
               options: [.prettyPrinted, .sortedKeys]
           ),
           let string = String(data: pretty, encoding: .utf8) {
            return string
        }
        if let text = String(data: data, encoding: .utf8) {
            return text
        }
        return "<\(data.count) bytes>"
    }
}

/// Lock-guarded, capacity-capped buffer of intercepted requests, read by the in-app inspector.
public final class NetworkActivityStore: @unchecked Sendable {
    public static let shared = NetworkActivityStore()

    private let lock = UnfairLock()
    private var records: [NetworkRequestRecord] = []
    private var storedCapacity = LoggingConstants.Defaults.maxNetworkViewerEntries

    init() {}

    public var capacity: Int {
        get { lock.withLock { storedCapacity } }
        set {
            lock.withLock {
                storedCapacity = max(1, newValue)
                trimLocked()
            }
        }
    }

    public func record(_ record: NetworkRequestRecord) {
        lock.withLock {
            records.append(record)
            trimLocked()
        }
    }

    /// Captured requests, oldest first.
    public func snapshot() -> [NetworkRequestRecord] {
        lock.withLock { records }
    }

    public func clear() {
        lock.withLock { records.removeAll() }
    }

    private func trimLocked() {
        if records.count > storedCapacity {
            records.removeFirst(records.count - storedCapacity)
        }
    }
}
