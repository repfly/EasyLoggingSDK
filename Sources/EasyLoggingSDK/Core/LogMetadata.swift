//
//  LogMetadata.swift
//
//

import Foundation

/// Type-safe container for log metadata.
///
/// Use `LogMetadata` instead of raw `[String: Any]` dictionaries for compile-time safety.
///
/// ```swift
/// var metadata = LogMetadata()
/// metadata["userId"] = "abc123"
/// metadata["retryCount"] = 3
/// metadata["latency"] = 0.245
/// logger.info("Request completed", metadata: metadata)
/// ```
public struct LogMetadata: Sendable, ExpressibleByDictionaryLiteral {
    private var storage: [String: String]

    public init() {
        self.storage = [:]
    }

    public init(dictionaryLiteral elements: (String, Any)...) {
        self.storage = [:]
        for (key, value) in elements {
            storage[key] = String(describing: value)
        }
    }

    /// Create from a Codable value. All fields are flattened to string key-value pairs.
    public init<T: Codable>(codable: T) {
        self.storage = [:]
        do {
            let data = try JSONEncoder().encode(codable)
            if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                for (key, value) in dict {
                    storage[key] = String(describing: value)
                }
            } else if let json = String(data: data, encoding: .utf8) {
                storage["data"] = json
            }
        } catch {
            storage["encoding_error"] = error.localizedDescription
        }
    }

    public subscript(key: String) -> Any? {
        get { storage[key] }
        set { storage[key] = newValue.map { String(describing: $0) } }
    }

    /// The underlying string dictionary used for formatting.
    public var stringDictionary: [String: String] {
        storage
    }

    public var isEmpty: Bool {
        storage.isEmpty
    }
}
