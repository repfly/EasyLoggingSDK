# EasyLoggingSDK

A Swift logging SDK for iOS that wraps CocoaLumberjack and Swift-log behind a single, batteries-included API.

## Features

- **Unified Interface** — one logger backed by industry-standard frameworks.
- **Swift 6 & Concurrency-Safe** — builds in the Swift 6 language mode with complete strict-concurrency checking; log delivery is FIFO-ordered through a serializing actor pipeline (`await logger.flush()` guarantees delivery).
- **One-Line Setup** — call `EasyLoggingSDK.activate()` at launch and every UIKit/SwiftUI feature is wired up.
- **Modular** — four products (Core / Network / UI / umbrella) so slim builds link only what they use.
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

EasyLoggingSDK.activate()        // once at launch — wires the viewer, screen tracking, shake-to-share

let logger = EasyLogger.shared
logger.info("App launched")
logger.debug("Cache hit", category: "storage")
```

Pure logging works without `activate()`; it is what attaches the opt-in UI and network-inspector features.

## Modules

The package ships four products, so you only link what you use:

| Product | What it contains | Depends on |
|---|---|---|
| `EasyLoggingCore` | The logging engine — configuration, levels, formats, metadata, redaction, file management. UIKit-free. | CocoaLumberjack, swift-log |
| `EasyLoggingNetwork` | Opt-in `URLProtocol` request interceptor and the in-memory network activity store. | Core |
| `EasyLoggingUI` | In-app log viewer, screen-time tracking, shake-to-share. UIKit/SwiftUI. | Core, Network |
| `EasyLoggingSDK` | Umbrella — re-exports the other three; `EasyLoggingSDK.activate()` wires everything up. | all of the above |

For a slim build, depend on `EasyLoggingCore` (and optionally `EasyLoggingNetwork`) directly; call `EasyLoggingUI.install()` instead of `activate()` if you link the UI layer without the umbrella.

## Requirements

- iOS 15.0+ / macOS 12.0+
- Swift 6.0+ (builds in the Swift 6 language mode)
- Xcode 16.0+

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