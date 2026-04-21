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
    private var redactableKeys: [String: RedactionLevel]

    public init() {
        self.storage = [:]
        self.redactableKeys = [:]
    }

    public init(dictionaryLiteral elements: (String, Any)...) {
        self.storage = [:]
        self.redactableKeys = [:]
        for (key, value) in elements {
            storage[key] = String(describing: value)
        }
    }

    /// Create from a Codable value. All fields are flattened to string key-value pairs.
    public init<T: Codable>(codable: T) {
        self.storage = [:]
        self.redactableKeys = [:]
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

    /// Store a value that should be redacted based on the given ``RedactionLevel``.
    ///
    /// ```swift
    /// metadata.setRedactable("user@example.com", forKey: "email", redaction: .auto)
    /// ```
    public mutating func setRedactable(_ value: Any, forKey key: String, redaction: RedactionLevel = .auto) {
        storage[key] = String(describing: value)
        redactableKeys[key] = redaction
    }

    /// The underlying string dictionary used for formatting.
    public var stringDictionary: [String: String] {
        storage
    }

    /// Returns a dictionary with redactable values replaced according to the current environment.
    /// - Parameter isProduction: Whether the current environment is production.
    /// - Returns: A dictionary with sensitive values replaced by `<REDACTED>` where appropriate.
    public func redactedDictionary(isProduction: Bool) -> [String: String] {
        var result = storage
        for (key, level) in redactableKeys {
            switch level {
            case .always:
                result[key] = "<REDACTED>"
            case .auto where isProduction:
                result[key] = "<REDACTED>"
            case .auto, .never:
                break
            }
        }
        return result
    }

    public var isEmpty: Bool {
        storage.isEmpty
    }
}
