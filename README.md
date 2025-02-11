# EasyLoggingSDK

A Swift logging SDK that simplifies logging implementation in iOS applications by providing a unified interface combining CocoaLumberjack and Swift-log.

## Features

- Unified logging interface
- Built on top of industry-standard logging frameworks
- iOS 12.0+ support
- Thread-safe logging
- Multiple log levels (Debug, Info, Warning, Error)
- Customizable log formatting

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/repfly/EasyLoggingSDK", from: "1.0.0")
]
```

## Usage

```swift
import EasyLoggingSDK

// Initialize the logger
let logger = EasyLogger.shared

// Log messages with different levels
logger.debug("Debug message")
logger.info("Info message")
logger.warning("Warning message")
logger.error("Error message")
```

## Requirements

- iOS 12.0+
- Swift 5.8+
- Xcode 14.0+

## Dependencies

- [CocoaLumberjack](https://github.com/CocoaLumberjack/CocoaLumberjack) (3.8.0+)
- [Swift-log](https://github.com/apple/swift-log) (1.4.0+)

## Documentation

For detailed documentation and examples, please visit the [documentation](./Documentation) directory.

## Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a list of changes and version history. 