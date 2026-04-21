//
//  RedactionLevel.swift
//
//

import Foundation

/// Controls when a metadata value is redacted in log output.
///
/// Use ``RedactionLevel`` together with ``LogMetadata/setRedactable(_:forKey:redaction:)``
/// to protect sensitive values such as tokens, emails, or user IDs.
///
/// ```swift
/// var metadata = LogMetadata()
/// metadata.setRedactable("user@example.com", forKey: "email", redaction: .auto)
/// // In production the value is replaced with "<REDACTED>"
/// ```
public enum RedactionLevel: Sendable {
    /// Redact in production environments only (default).
    case auto
    /// Always redact regardless of environment.
    case always
    /// Never redact — the value appears in plain text everywhere.
    case never
}
