# Getting Started with EasyLoggingSDK

A comprehensive guide to installing, configuring, and using every feature of the SDK.

## Installation

Add the package via **Swift Package Manager**:

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/repfly/EasyLoggingSDK", from: "2.0.0")
]
```

Or in Xcode: **File → Add Package Dependency** → paste the URL above.

## Quick Start

```swift
import EasyLoggingSDK

let logger = EasyLogger.shared
logger.info("App launched")
```

No additional setup is needed — the SDK hooks into the UIKit lifecycle automatically.

## Configuration

### Environment Presets

Call `setEnvironment` once at launch. The setting persists across launches.

```swift
logger.setEnvironment(.production)
```

| Environment    | Min Level | Console | File | Extras |
|----------------|-----------|---------|------|--------|
| `.development` | debug     | ✓       | ✓    | Shake-to-share, log viewer, screen tracking |
| `.staging`     | info      | —       | ✓    | Log viewer |
| `.production`  | warning   | —       | ✓    | — |

### Custom Configuration

```swift
var config = EasyLogger.Configuration()
config.minimumLogLevel = .debug
config.shouldLogToFile = true
config.logFormat = .detailed
logger.configure(config)
```

## Features

### Logging & Levels

Six levels, ordered by severity: `trace`, `debug`, `info`, `warning`, `error`, `critical`.

```swift
logger.trace("Entering function")
logger.debug("Cache hit")
logger.info("User signed in")
logger.warning("Disk space low")
logger.error("Failed to save")
logger.critical("Unrecoverable state")
```

Messages use `@autoclosure` so expensive interpolations are only evaluated when the level is enabled.

### Log Categories

Tag logs with a subsystem name for filtering.

```swift
logger.info("Token refreshed", category: "auth")
logger.debug("Response received", category: "networking")
```

Categories appear in the log output via the `%category` format placeholder and are searchable in the in-app log viewer.

### Metadata

Attach structured context to any log message. `LogMetadata` is the single, `Sendable` metadata
type — it is the one currency every logging API accepts.

```swift
// Dictionary literal
logger.info("Order placed", metadata: ["orderId": "abc123", "total": 49.99])

// From a Codable value (top-level keys are flattened)
struct Order: Codable { let id: String; let total: Double }
logger.info("Order placed", metadata: LogMetadata(codable: Order(id: "abc123", total: 49.99)))

// Built incrementally
var meta = LogMetadata()
meta["userId"] = "u_42"
meta["latency"] = 0.245
logger.info("Request completed", metadata: meta)
```

> Redaction protects metadata values, not the message string. Pass sensitive values as metadata
> rather than interpolating them into the message.

### Privacy Redaction

Sensitive values are replaced with `<REDACTED>`. Keys that look sensitive (e.g. `password`,
`token`, `authorization`, `apiKey`, `secret`) are redacted **automatically on every path** — including
dictionary literals and `LogMetadata(codable:)` — so the most natural call never leaks:

```swift
logger.error("Login failed", metadata: ["password": pw, "userId": id])
// → password is <REDACTED>, userId is shown
```

Use `setRedactable` for explicit control (it overrides the automatic default):

```swift
var meta = LogMetadata()
meta.setRedactable("user@example.com", forKey: "email", redaction: .auto)   // redacted in production
meta.setRedactable("sk_live_abc",      forKey: "apiKey", redaction: .always) // always redacted
meta["requestId"] = "req_123"                                                // never redacted
logger.info("Auth request", metadata: meta)
```

Redaction levels: `.auto` (production only, default), `.always`, `.never`.

### Screen Time Tracking

#### UIKit — Automatic

```swift
var config = EasyLogger.Configuration()
config.trackScreenLoadingTimes = true
config.useAutomaticUIKitScreenTimeTracking = true
config.slowScreenLoadingThreshold = 0.5 // seconds
logger.configure(config)
```

The SDK swizzles `viewWillAppear`/`viewDidAppear` and logs load times automatically. System VCs are excluded.

#### SwiftUI — View Modifier

```swift
struct ProfileView: View {
    var body: some View {
        Text("Profile")
            .trackScreenTime(screenName: "ProfileView")
    }
}
```

Additional modifiers: `.trackScreenTimeWithMetadata(screenName:metadata:)` and `.trackScreenTimeWithTransitions(screenName:)`.

#### SwiftUI — Manual

```swift
struct SettingsView: View {
    var body: some View {
        List { /* ... */ }
            .onAppear  { EasyLogger.shared.trackScreenAppearance(name: "SettingsView") }
            .onDisappear { EasyLogger.shared.endScreenTracking(name: "SettingsView") }
    }
}
```

Screens that exceed `slowScreenLoadingThreshold` are logged at **warning** level.

### Network Request Logging

Opt-in `URLProtocol`-based interceptor. Logs method, URL, status code, duration, and body sizes.

```swift
var config = EasyLogger.Configuration()
config.enableNetworkLogging = true
logger.configure(config)

let sessionConfig = logger.networkLoggingSessionConfiguration()
let session = URLSession(configuration: sessionConfig)
// All requests through this session are now logged under the "network" category.
```

### In-App Log Viewer

A full-screen overlay for QA testers. Supports search, level filtering, and log sharing.

```swift
var config = EasyLogger.Configuration()
config.enableInAppLogViewer = true
config.logViewerActivationGesture = .shake       // or .longPress / .none
config.maxLogViewerEntries = 1000
logger.configure(config)

// Or open programmatically
logger.showInAppLogViewer()
```

### Crash Diagnostics (Out of Scope)

EasyLoggingSDK does **not** capture crashes. An in-process `NSSetUncaughtExceptionHandler`
misses most Swift runtime crashes and signals (e.g. `fatalError`, force-unwraps, `EXC_BAD_ACCESS`),
does unsafe work inside a dying process, and clobbers any other crash reporter the app installs.

For crash diagnostics, use Apple's [MetricKit](https://developer.apple.com/documentation/metrickit)
(`MXCrashDiagnostic` via `MXMetricManager`), which the system delivers safely on the next launch,
or a dedicated crash-reporting service.

### Log Formats

Choose a preset or create your own.

| Preset      | Template |
|-------------|----------|
| `.default`  | `[%level] %file:%line %function - %message %metadata` |
| `.simple`   | `%level: %message` |
| `.detailed` | `%date [%level] %file:%line %function - %message %metadata` |
| `.json`     | `{"timestamp":"%date","level":"%levelRaw",...}` |
| `.clean`    | `[%level] %message %metadata` |

Available placeholders: `%date`, `%level`, `%levelRaw`, `%category`, `%file`, `%line`, `%function`, `%message`, `%metadata`.

```swift
config.logFormat = LogFormat(template: "%date [%category] %level: %message")
```

### File Management

```swift
// Get current log file URL
let url = await logger.getCurrentLogFileURL()

// Rotate the log file
logger.rotateLogFile()

// Delete all log files
logger.removeAllLogFiles()
```

## Async / Await

Logging and configuration methods provide same-name `async` overloads. In an `async` context,
call them with `await` and the async overload is selected automatically; the call returns only
after the work has been flushed and delivered.

```swift
await logger.info("Background work done")
await logger.configure(config)
await logger.setEnvironment(.production)
await logger.flush()
```

## Best Practices

- **Use appropriate levels** — `debug` for development noise, `error` for failures only.
- **Use categories** — makes filtering in the log viewer and in production monitoring much easier.
- **Mark sensitive data as redactable** — never log passwords, tokens, or PII in plain text. Use `LogMetadata.setRedactable(_:forKey:redaction:)`.
- **Leverage `@autoclosure`** — the SDK already defers message evaluation, but avoid placing heavy work inside metadata dictionaries.
- **Review production config** — ensure `minimumLogLevel` is `.warning` or higher and `shouldLogToConsole` is `false`.