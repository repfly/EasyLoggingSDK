# Getting Started with EasyLoggingSDK

This guide will help you get started with EasyLoggingSDK in your iOS application.

## Installation

### Swift Package Manager

1. In Xcode, select File > Add Package Dependency.
2. Enter the repository URL: `https://github.com/repfly/EasyLoggingSDK`
3. Select the version you want to use (e.g., `2.0.0` or newer).

Or add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/repfly/EasyLoggingSDK", from: "2.0.0")
]
```

## Initial Setup

No manual setup required! The SDK automatically integrates with your application's lifecycle. Just import the SDK and start logging.

## Basic Usage

### Initialize the Logger

```swift
import EasyLoggingSDK

// Get the shared instance
let logger = EasyLogger.shared

// Start logging!
logger.info("EasyLoggingSDK is ready!")
```

### Environment-Based Configuration

EasyLoggingSDK supports different logging configurations based on your app's environment. You can optionally configure the environment at startup.

```swift
// Use a default environment configuration
logger.setupEnvironment(.development)

// Or use a custom configuration for an environment
var customConfig = EasyLogger.Configuration()
customConfig.minimumLogLevel = .debug
customConfig.shouldLogToConsole = true
logger.setupEnvironment(.staging, customConfiguration: customConfig)
```

#### Available Environments

1.  **Development** (`.development`)
2.  **Staging** (`.staging`)
3.  **Production** (`.production`)
4.  **Custom** (`.custom`)

The environment setting persists across app launches.

### Logging Messages

```swift
// Debug level
logger.debug("This is a debug message")

// Info level
logger.info("This is an info message")

// Warning level
logger.warning("This is a warning message")

// Error level
logger.error("This is an error message")
```

## Advanced Usage

### Screen Time Tracking

Monitor your app's screen loading performance. The SDK supports both `UIKit` and `SwiftUI`.

#### Tracking UIKit ViewControllers

The SDK can automatically track all your view controllers.

```swift
// Enable screen time tracking in your configuration
var config = EasyLogger.Configuration()
config.trackScreenLoadingTimes = true
config.useAutomaticScreenTimeTracking = true // This is the default
config.slowScreenLoadingThreshold = 0.5 // Set warning threshold to 500ms
logger.configure(config)

// No other code is needed!
```

#### Tracking SwiftUI Views

For SwiftUI, you can manually track view appearance by using the `.onAppear` and `.onDisappear` modifiers.

```swift
// 1. Enable screen time tracking in your configuration
var config = EasyLogger.Configuration()
config.trackScreenLoadingTimes = true
logger.configure(config)

// 2. Use the tracking modifiers in your view
import SwiftUI
import EasyLoggingSDK

struct MySwiftUIView: View {
    private let screenName = "MySwiftUIView"

    var body: some View {
        Text("Hello, SwiftUI!")
            .onAppear {
                EasyLogger.shared.trackViewAppearance(name: screenName)
            }
            .onDisappear {
                EasyLogger.shared.endViewTracking(name: screenName)
            }
    }
}
```

The SDK will automatically:
- Track loading/appearance time for each screen/view.
- Log normal times at the `debug` level.
- Log warnings for screens/views that take longer than the configured threshold.

### Memory Leak Detection

The SDK includes a powerful memory leak detection system.

```swift
// Enable memory leak detection in configuration
var config = EasyLogger.Configuration()
config.enableMemoryLeakDetection = true
logger.configure(config)

// Monitor specific objects
class MyViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        EasyLogger.shared.monitorForLeaks(self)
    }
}
```

### In-App Log Viewer for QA Testing

EasyLoggingSDK includes an in-app log viewer that allows QA testers to view logs directly within the app.

```swift
// Enable the in-app log viewer in your configuration
var config = EasyLogger.Configuration()
config.enableInAppLogViewer = true
config.logViewerAccessCode = "123456" // Optional: for security
logger.configure(config)
```

## Best Practices

1.  **Log Levels**: Use appropriate log levels (debug, info, warning, error).
2.  **Performance**: Avoid expensive operations in log messages. The SDK uses `@autoclosure` to help, but it's good practice to be mindful.
3.  **Sensitive Data**: Never log passwords, API keys, or personal user data.