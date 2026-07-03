# ``EasyLoggingSDK``

A batteries-included Swift logging SDK for iOS and macOS that wraps CocoaLumberjack and
swift-log behind a single, thread-safe, privacy-aware API.

@Metadata {
    @DisplayName("EasyLoggingSDK")
}

## Overview

`EasyLoggingSDK` is the umbrella module: importing it re-exports the three feature modules,
and calling ``EasyLoggingSDK/activate()`` once at launch wires up the opt-in features.

```swift
import EasyLoggingSDK

EasyLoggingSDK.activate()   // attaches the in-app viewer, screen tracking, shake-to-share

let logger = EasyLogger.shared
logger.info("App launched")
logger.debug("Cache hit", category: "storage")
```

Pure logging works without `activate()` — it is what attaches the UIKit/SwiftUI layer and
keeps the network inspector's store in sync with your configuration.

The package is split so you only link what you use:

- `EasyLoggingCore` — the logging engine: `EasyLogger`, `EasyLogger.Configuration`,
  `LogLevel`, `LogFormat`, `LogEnvironment`, `LogMetadata`, and `RedactionLevel`.
  UIKit-free; documented in the `EasyLoggingCore` module.
- `EasyLoggingNetwork` — the opt-in `URLProtocol` request interceptor (`NetworkLogger`)
  and the in-memory `NetworkActivityStore` behind the network inspector.
- `EasyLoggingUI` — the in-app log viewer, screen-time tracking, and shake-to-share.
  Slim builds that link it without the umbrella call `EasyLoggingUI.install()` instead
  of `activate()`.

## Getting Started

Pick an environment preset for a one-line setup, or build a custom `EasyLogger.Configuration`:

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
and `LogMetadata`:

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
automatically. For explicit control, use `LogMetadata.setRedactable(_:forKey:redaction:)`
with a `RedactionLevel`:

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

- `EasyLogger` is `Sendable`; its mutable state is hand-synchronized with an
  `os_unfair_lock` (the textbook annotation for an iOS 15 / macOS 12 target).
- All log delivery flows through one `Sendable` serial pipeline that preserves FIFO order.
- `LogMetadata` and `EasyLogger.Configuration` are value types and `Sendable`, so they
  cross actor boundaries safely.
- Every public method has an `async` variant; use `await logger.flush()` to guarantee all
  enqueued records are processed (for example before app exit).
