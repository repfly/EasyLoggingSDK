# ``EasyLoggingSDK``

A batteries-included Swift logging SDK for iOS and macOS that wraps CocoaLumberjack and
swift-log behind a single, thread-safe, privacy-aware API.

@Metadata {
    @DisplayName("EasyLoggingSDK")
}

## Overview

`EasyLoggingSDK` gives you one logger — ``EasyLogger/shared`` — backed by industry-standard
frameworks. It is thread-safe, redacts sensitive metadata automatically, and ships with
opt-in UIKit lifecycle integration, network logging, screen-time tracking, and an in-app log
viewer.

```swift
import EasyLoggingSDK

let logger = EasyLogger.shared
logger.info("App launched")
logger.debug("Cache hit", category: "storage")
```

Every public logging call is funneled through a single serial pipeline, so log lines,
configuration changes, and flush markers are always delivered in strict FIFO order.

## Getting Started

Pick an environment preset for a one-line setup, or build a custom
``EasyLogger/Configuration``:

```swift
// Environment preset
EasyLogger.shared.setEnvironment(.production)

// Or a custom configuration
var config = EasyLogger.Configuration()
config.minimumLogLevel = .warning
config.shouldLogToFile = true
config.logFormat = .detailed
EasyLogger.shared.configure(config)
```

Log at any severity using the level convenience methods. Each accepts an optional `category`
and ``LogMetadata``:

```swift
logger.trace("Entered function")
logger.debug("Parsed response", category: "network")
logger.info("User signed in", metadata: ["userId": "abc123"])
logger.warning("Low disk space")
logger.error("Request failed", metadata: ["status": 500])
logger.critical("Unrecoverable state")
```

## Privacy

Redaction protects **metadata** values — never interpolate secrets into the message string.
Keys that look sensitive (for example `password`, `token`, `authorization`) are redacted
automatically. For explicit control, use ``LogMetadata/setRedactable(_:forKey:redaction:)``
with a ``RedactionLevel``:

```swift
var metadata = LogMetadata()
metadata.setRedactable("user@example.com", forKey: "email", redaction: .auto)
// `.auto`   — redacted in the `.production` environment only
// `.always` — redacted everywhere
// `.never`  — never redacted
```

Redaction happens before any value crosses the logging actor boundary, so the in-app viewer's
in-memory buffer and the on-disk files only ever see redacted metadata.

## Concurrency

`EasyLoggingSDK` is built in the **Swift 6 language mode** with complete strict-concurrency
checking — both the library and its tests compile cleanly with no concurrency warnings:

- ``EasyLogger`` is `Sendable`; its mutable state is hand-synchronized with an
  `os_unfair_lock` (the textbook annotation for an iOS 15 / macOS 12 target).
- All log delivery flows through one `Sendable` serial pipeline that preserves FIFO order.
- ``LogMetadata`` and ``EasyLogger/Configuration`` are value types and `Sendable`, so they
  cross actor boundaries safely.
- Every public method has an `async` variant; use `await logger.flush()` to guarantee all
  enqueued records are processed (for example before app exit).

## Topics

### Essentials

- ``EasyLogger``
- ``EasyLogger/Configuration``
- ``LogLevel``

### Metadata & Privacy

- ``LogMetadata``
- ``RedactionLevel``

### Formatting & Environments

- ``LogFormat``
- ``LogEnvironment``

### Network Logging

- ``NetworkLogger``
