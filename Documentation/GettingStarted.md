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

Call `setupEnvironment` once at launch. The setting persists across launches.

```swift
logger.setupEnvironment(.production)
```

| Environment    | Min Level | Console | File | Crash Detection | Extras |
|----------------|-----------|---------|------|-----------------|--------|
| `.development` | debug     | ✓       | ✓    | ✓               | Shake-to-share, log viewer, screen tracking |
| `.staging`     | info      | —       | ✓    | ✓               | Log viewer |
| `.production`  | warning   | —       | ✓    | ✓               | — |

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

Four levels, ordered by severity: `debug`, `info`, `warning`, `error`.

```swift
logger.debug("Cache hit")
logger.info("User signed in")
logger.warning("Disk space low")
logger.error("Failed to save")
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

Attach structured context to any log message.

```swift
// Dictionary metadata
logger.info("Order placed", metadata: ["orderId": "abc123", "total": 49.99])

// Codable metadata
struct Order: Codable { let id: String; let total: Double }
logger.info("Order placed", metadata: Order(id: "abc123", total: 49.99))

// Type-safe LogMetadata
var meta = LogMetadata()
meta["userId"] = "u_42"
meta["latency"] = 0.245
logger.info("Request completed", metadata: meta)
```

### Privacy Redaction

Mark sensitive values so they are automatically replaced with `<REDACTED>` in production.

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

### Crash Detection

Enabled by default. On an uncaught exception the SDK:

1. Writes a full crash report (name, reason, stack trace) to the log file.
2. Sets a crash flag in `UserDefaults`.
3. On next launch, logs a warning if the previous session crashed.

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

Every logging and configuration method has an `async` variant:

```swift
await logger.infoAsync("Background work done")
await logger.configureAsync(config)
await logger.setupEnvironmentAsync(.production)
```

## Best Practices

- **Use appropriate levels** — `debug` for development noise, `error` for failures only.
- **Use categories** — makes filtering in the log viewer and in production monitoring much easier.
- **Mark sensitive data as redactable** — never log passwords, tokens, or PII in plain text. Use `LogMetadata.setRedactable(_:forKey:redaction:)`.
- **Leverage `@autoclosure`** — the SDK already defers message evaluation, but avoid placing heavy work inside metadata dictionaries.
- **Review production config** — ensure `minimumLogLevel` is `.warning` or higher and `shouldLogToConsole` is `false`.