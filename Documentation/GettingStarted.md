# Getting Started with EasyLoggingSDK

This guide will help you get started with EasyLoggingSDK in your iOS application.

## Installation

### Swift Package Manager

1. In Xcode, select File > Swift Packages > Add Package Dependency
2. Enter the repository URL
3. Select the version you want to use

Or add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "YOUR_REPOSITORY_URL", from: "1.0.0")
]
```

## Basic Usage

### Initialize the Logger

```swift
import EasyLoggingSDK

// Get the shared instance
let logger = EasyLogger.shared

// Optional: Configure the logger
logger.configure(minimumLogLevel: .debug,
                shouldLogToConsole: true,
                shouldLogToFile: true)
```

### Environment-Based Configuration

EasyLoggingSDK supports different logging configurations based on your app's environment:

```swift
// Use default environment configuration
logger.setupEnvironment(.development)

// Or use custom configuration for an environment
var customConfig = EasyLogger.Configuration()
customConfig.minimumLogLevel = .debug
customConfig.shouldLogToConsole = true
logger.setupEnvironment(.staging, customConfiguration: customConfig)
```

#### Available Environments

1. **Development** (.development)
   - Debug level logging
   - Console and file logging enabled
   - Shake to share enabled
   - Detailed log format
   - 10MB max file size

2. **Staging** (.staging)
   - Info level logging
   - Console and file logging enabled
   - Shake to share enabled
   - Default log format
   - 5MB max file size

3. **Production** (.production)
   - Warning level logging
   - File logging only
   - Shake to share disabled
   - Simple log format
   - 2MB max file size

4. **Custom** (.custom)
   - Fully customizable configuration

The environment setting persists across app launches and can be checked at any time:

```swift
// Check current environment
if logger.environment == .production {
    // Production-specific code
}
```

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

### Advanced Usage

#### Custom Log Formatting

```swift
logger.configure(format: "[%level] %message")
```

#### Log File Management

```swift
// Get log file URL
if let logFileURL = logger.currentLogFileURL {
    // Handle log file
}

// Rotate log files
logger.rotateLogFile()
```

#### Screen Loading Time Tracking

Monitor your app's screen loading performance. The SDK supports both automatic and manual tracking:

#### Memory Leak Detection

The SDK includes a powerful memory leak detection system that can help identify potential retain cycles and memory leaks:

```swift
// Enable memory leak detection in configuration
var config = EasyLogger.Configuration()
config.enableMemoryLeakDetection = true
config.memoryLeakCheckInterval = 5.0 // Check every 5 seconds
logger.configure(config)

// Monitor specific objects
class MyViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        EasyLogger.shared.monitorForLeaks(self)
    }
    
    deinit {
        EasyLogger.shared.stopMonitoringForLeaks(self)
    }
}
```

The memory leak detector will:
- Monitor objects for proper deallocation
- Detect view controllers that might be retained after dismissal
- Provide detailed logs with object lifecycle information
- Include memory addresses and retain cycle hints

Example log output:
```
[WARNING] Potential memory leak detected [object_type:MyViewController] [lifetime:65.32 seconds] [address:0x7f8c2e70b600]
[DEBUG] View Controller details [parent:nil] [presenting:nil] [presented:nil] [has_window:false]
```

Memory leak detection is:
- Enabled by default in development environment
- Enabled with longer intervals in staging
- Disabled in production for performance

##### Automatic Tracking (Recommended)

```swift
// Configure screen time tracking
var config = EasyLogger.Configuration()
config.trackScreenLoadingTimes = true
config.useAutomaticScreenTimeTracking = true // Enable automatic tracking (default: true)
config.slowScreenLoadingThreshold = 0.5 // Set warning threshold to 500ms
logger.configure(config)

// That's it! The SDK will automatically track all your view controllers
```

The automatic tracking:
- Uses method swizzling to track all view controllers
- Automatically excludes system view controllers
- Requires no code changes in your view controllers
- Can be disabled for specific view controllers if needed

##### Manual Tracking (Alternative)

If you prefer manual control, you can disable automatic tracking and add the tracking calls yourself:

```swift
// Configure manual tracking
var config = EasyLogger.Configuration()
config.trackScreenLoadingTimes = true
config.useAutomaticScreenTimeTracking = false // Disable automatic tracking
config.slowScreenLoadingThreshold = 0.5
logger.configure(config)

// In your view controllers:
class MyViewController: UIViewController {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        EasyLogger.shared.trackScreenAppearance(self)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        EasyLogger.shared.endScreenTracking(self)
    }
}
```

The SDK will automatically:
- Track loading time for each screen
- Log normal loading times at debug level
- Log warnings for screens that take longer than the threshold
- Include screen name, duration, and tracking method in the logs

Example log output:
```
[DEBUG] MyViewController loaded [screen:MyViewController] [duration:0.234] [tracking_method:automatic]
[WARNING] Slow screen loading detected [screen:SlowViewController] [duration:1.543] [tracking_method:automatic]
```

### Async/Await Support

For iOS 13.0 and later, EasyLoggingSDK provides async/await support for all major operations:

```swift
// Async logging
await logger.debugAsync("Debug message")
await logger.infoAsync("Info message")
await logger.warningAsync("Warning message")
await logger.errorAsync("Error message")

// Async configuration
await logger.setupEnvironmentAsync(.development)

// Async file management
await logger.rotateLogFileAsync()
await logger.removeAllLogFilesAsync()

// Async memory leak detection
await logger.monitorForLeaksAsync(object)
await logger.stopMonitoringForLeaksAsync(object)

// Async screen time tracking
await logger.trackScreenAppearanceAsync(viewController)
if let duration = await logger.endScreenTrackingAsync(viewController) {
    print("Screen loaded in \(duration) seconds")
}
```

The async API provides the same functionality as the synchronous API but with better integration into modern Swift concurrency patterns. Legacy completion-based APIs are still available for backward compatibility.

## Best Practices

1. **Log Levels**: Use appropriate log levels
   - Debug: Detailed information for debugging
   - Info: General information about app operation
   - Warning: Potentially harmful situations
   - Error: Error events that might still allow the app to continue running

2. **Performance**: Avoid expensive operations in log messages
   ```swift
   // Bad
   logger.debug("User data: \(expensiveOperation())")
   
   // Good
   if logger.isDebugEnabled {
       logger.debug("User data: \(expensiveOperation())")
   }
   ```

3. **Sensitive Data**: Never log sensitive information
   ```swift
   // Bad
   logger.debug("User password: \(password)")
   
   // Good
   logger.debug("User authenticated successfully")
   ```

## Troubleshooting

### Common Issues

1. **Logs not appearing**
   - Check minimum log level configuration
   - Verify console output is enabled
   - Check file permissions if logging to file

2. **Performance Issues**
   - Reduce log verbosity in production
   - Use appropriate log levels
   - Implement log rotation 