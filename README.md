# EasyLoggingSDK

A Swift logging SDK that simplifies logging implementation in iOS applications by providing a unified interface combining CocoaLumberjack and Swift-log.

## Features

- Unified logging interface built on industry-standard logging frameworks.
- **Thread-Safe**: All logging and configuration operations are fully thread-safe.
- **Automatic Lifecycle**: No-setup integration with the UIKit application lifecycle.
- **SwiftUI Ready**: Core logger is platform-agnostic. Includes helpers for SwiftUI view tracking.
- **Rich Feature Set**: Includes crash detection, file logging, screen time tracking, memory leak detection, and an in-app log viewer.
- **Highly Configurable**: Customize log levels, formats, and features based on environments (e.g., development, staging, production).

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/repfly/EasyLoggingSDK", from: "2.0.0")
]
```

Or add the package via Xcode's UI.

## Basic Usage

```swift
import EasyLoggingSDK

// The SDK is automatically configured. Just get the shared instance and start logging.
let logger = EasyLogger.shared

// Log messages with different levels
logger.debug("Debug message")
logger.info("Info message")
logger.warning("Warning message")
logger.error("Error message")
```

## Requirements

- iOS 15.0+
- Swift 5.9+
- Xcode 15.0+

## Dependencies

- [CocoaLumberjack](https://github.com/CocoaLumberjack/CocoaLumberjack) (3.8.0+)
- [Swift-log](https://github.com/apple/swift-log) (1.4.0+)

## Documentation

For detailed documentation and usage examples, including how to configure features like SwiftUI screen tracking, please visit the [documentation](./Documentation) directory.

## Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a list of changes and version history.