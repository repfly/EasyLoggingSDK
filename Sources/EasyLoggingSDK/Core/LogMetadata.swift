//
//  LogMetadata.swift
//
//

import Foundation

/// A typed, `Sendable` container for log metadata.
///
/// `LogMetadata` is the single metadata currency for the SDK. It stores values in a typed,
/// `Sendable` representation (values are typed-at-rest, not `String`-flattened on insertion) and
/// defers stringification until *after* redaction is applied, so sensitive values never leak
/// through eager `String(describing:)` conversion. Keys that look sensitive (e.g. `password`,
/// `token`, `authorization`) are redacted by default — see ``setRedactable(_:forKey:redaction:)``
/// to override.
///
/// ```swift
/// var metadata = LogMetadata()
/// metadata["userId"] = "abc123"
/// metadata["retryCount"] = 3
/// metadata["latency"] = 0.245
/// logger.info("Request completed", metadata: metadata)
/// ```
public struct LogMetadata: Sendable, ExpressibleByDictionaryLiteral {

    /// Typed, `Sendable` storage for a metadata value.
    ///
    /// Scalars keep their native type so redaction can run before stringification.
    /// Anything that is not a recognized scalar is captured as `.other` using
    /// `String(describing:)` at insertion time.
    enum StoredValue: Sendable {
        case string(String)
        case int(Int)
        case double(Double)
        case bool(Bool)
        case other(String)

        /// The string representation used in final log output.
        var described: String {
            switch self {
            case let .string(value): return value
            case let .int(value): return String(value)
            case let .double(value): return String(value)
            case let .bool(value): return String(value)
            case let .other(value): return value
            }
        }

        /// Wraps an arbitrary value into a typed `StoredValue`.
        ///
        /// `Bool` is matched before `Int` because `Bool` bridges to `NSNumber` and would
        /// otherwise be captured as an integer.
        static func wrap(_ value: Any) -> StoredValue {
            switch value {
            case let bool as Bool:
                return .bool(bool)
            case let int as Int:
                return .int(int)
            case let double as Double:
                return .double(double)
            case let string as String:
                return .string(string)
            default:
                return .other(String(describing: value))
            }
        }
    }

    private var storage: [String: StoredValue]
    private var redactionLevels: [String: RedactionLevel]

    /// Key-name substrings (case-insensitive) that mark a value as a secret.
    ///
    /// Any key containing one of these is redacted by default (``RedactionLevel/always``),
    /// regardless of which insertion path or overload was used — defense in depth so that the
    /// most natural call, `["password": pw]`, never leaks. An explicit
    /// ``setRedactable(_:forKey:redaction:)`` always wins over this default.
    private static let sensitiveKeyPatterns = [
        "password", "passwd", "pwd", "secret", "token",
        "authorization", "apikey", "api_key", "accesstoken", "access_token",
        "refreshtoken", "refresh_token", "credential", "privatekey", "private_key",
        "sessionid", "session_id", "cvv", "ssn"
    ]

    private static func isSensitive(_ key: String) -> Bool {
        let lowercased = key.lowercased()
        return sensitiveKeyPatterns.contains { lowercased.contains($0) }
    }

    /// Stores a value and auto-marks it redactable when the key looks sensitive,
    /// unless an explicit redaction level has already been set for that key.
    private mutating func store(_ value: Any, forKey key: String) {
        storage[key] = StoredValue.wrap(value)
        if redactionLevels[key] == nil, Self.isSensitive(key) {
            redactionLevels[key] = .always
        }
    }

    public init() {
        self.storage = [:]
        self.redactionLevels = [:]
    }

    public init(dictionaryLiteral elements: (String, Any)...) {
        self.storage = [:]
        self.redactionLevels = [:]
        for (key, value) in elements {
            store(value, forKey: key)
        }
    }

    /// Create from a `Codable` value. This is the single `Codable` -> metadata path.
    ///
    /// Top-level JSON object keys are flattened: numbers, booleans, and strings keep their
    /// type (via ``StoredValue/wrap(_:)``); nested arrays/objects are stored as `.other`. Non-object
    /// JSON (e.g. arrays) is stored under the `data` key. Any encoding failure is surfaced
    /// under the `metadata_error` key.
    public init<T: Codable>(codable: T) {
        self.storage = [:]
        self.redactionLevels = [:]
        do {
            let data = try JSONEncoder().encode(codable)
            let jsonObject = try JSONSerialization.jsonObject(with: data)
            if let dict = jsonObject as? [String: Any] {
                for (key, value) in dict {
                    store(value is NSNull ? "null" : value, forKey: key)
                }
            } else if let json = String(data: data, encoding: .utf8) {
                storage["data"] = .string(json)
            }
        } catch {
            storage["metadata_error"] = .string(error.localizedDescription)
        }
    }

    /// Get the described string for a key, or set a value (stored typed via ``StoredValue/wrap(_:)``).
    ///
    /// The getter returns the stringified value so existing call sites that read metadata
    /// keep compiling; the setter accepts `Any?` and defers stringification.
    public subscript(key: String) -> Any? {
        get { storage[key]?.described }
        set {
            if let newValue = newValue {
                store(newValue, forKey: key)
            } else {
                storage[key] = nil
                redactionLevels[key] = nil
            }
        }
    }

    /// Store a value that should be redacted based on the given ``RedactionLevel``.
    ///
    /// ```swift
    /// metadata.setRedactable("user@example.com", forKey: "email", redaction: .auto)
    /// ```
    public mutating func setRedactable(_ value: Any, forKey key: String, redaction: RedactionLevel = .auto) {
        storage[key] = StoredValue.wrap(value)
        redactionLevels[key] = redaction
    }

    /// The underlying string dictionary used for formatting.
    ///
    /// This is the *raw*, non-redacted view. Use ``redactedDictionary(isProduction:)`` for
    /// any output path.
    var stringDictionary: [String: String] {
        storage.mapValues { $0.described }
    }

    /// Returns a dictionary with redactable values replaced according to the current environment.
    ///
    /// This is the single place that produces the final `[String: String]`: the redaction
    /// decision is made on the typed value, and stringification happens *after* that decision.
    ///
    /// - Parameter isProduction: Whether the current environment is production.
    /// - Returns: A dictionary with sensitive values replaced by `<REDACTED>` where appropriate.
    ///
    /// Intentionally `internal`: only the logging pipeline may decide the environment, so callers
    /// cannot obtain unredacted `.auto` values by passing `isProduction: false`.
    func redactedDictionary(isProduction: Bool) -> [String: String] {
        var result: [String: String] = [:]
        for (key, value) in storage {
            switch redactionLevels[key] {
            case .always:
                result[key] = "<REDACTED>"
            case .auto where isProduction:
                result[key] = "<REDACTED>"
            case .auto, .never, .none:
                result[key] = value.described
            }
        }
        return result
    }

    public var isEmpty: Bool {
        storage.isEmpty
    }
}
