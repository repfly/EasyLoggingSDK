# EasyLoggingSDK

A Swift logging SDK for iOS that wraps CocoaLumberjack and Swift-log behind a single, batteries-included API.

## Features

- **Unified Interface** — one logger backed by industry-standard frameworks.
- **Thread-Safe** — all operations use `os_unfair_lock` and serial queues.
- **Zero-Setup Lifecycle** — hooks into UIKit automatically; no `AppDelegate` code needed.
- **SwiftUI Ready** — `.trackScreenTime(screenName:)` view modifier and manual tracking helpers.
- **Log Categories** — tag messages with a subsystem (`"auth"`, `"networking"`, …) for filtering.
- **Privacy Redaction** — mark metadata values as `.auto`, `.always`, or `.never` redacted; sensitive data is replaced with `<REDACTED>` in production.
- **Network Logging** — opt-in `URLProtocol` interceptor logs every request's method, URL, status, and duration.
- **Screen Time Tracking** — automatic UIKit swizzling or manual SwiftUI tracking with slow-load warnings.
- **In-App Log Viewer** — searchable, filterable overlay for QA, fed from the in-memory since-launch buffer.
- **Customisable Formats** — template-based log formatting with `%date`, `%level`, `%category`, `%message`, and more.
- **Async/Await** — every public method has an `async` variant.

## Installation

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/repfly/EasyLoggingSDK", from: "2.0.0")
]
```

Or in Xcode: **File → Add Package Dependency** → paste the URL.

## Quick Start

```swift
import EasyLoggingSDK

let logger = EasyLogger.shared
logger.info("App launched")
logger.debug("Cache hit", category: "storage")
```

## Requirements

- iOS 15.0+
- Swift 5.9+
- Xcode 15.0+

## Dependencies

- [CocoaLumberjack](https://github.com/CocoaLumberjack/CocoaLumberjack) (3.8.0+)
- [Swift-log](https://github.com/apple/swift-log) (1.4.0+)

## Documentation

See the [Getting Started guide](./Documentation/GettingStarted.md) for installation, configuration, and usage of every feature.

## Contributing

Contributions welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT — see [LICENSE](LICENSE).

## Changelog

See [CHANGELOG.md](CHANGELOG.md).