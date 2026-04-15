# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2025-08-10

### Added
- **Thread Safety**: All SDK operations are now fully thread-safe, preventing race conditions and ensuring stability in concurrent environments.
- **SwiftUI Support**: Added screen time tracking for SwiftUI views via `trackViewAppearance(name:)` and `endViewTracking(name:)`.
- **Automatic Lifecycle Management**: The SDK now automatically hooks into the `UIKit` application lifecycle, removing the need for manual setup in the `AppDelegate`.

### Changed
- **Decoupled from UIKit**: The core logging engine is now independent of `UIKit`, allowing it to be used in non-UI applications (e.g., server-side Swift, command-line tools).
- **Modular UI Components**: `UIKit`-specific features (Lifecycle Management, Shake-to-Share) have been moved into separate, self-contained components.
- **ScreenTimeTracker**: The helper class was refactored to support both `UIKit` and `SwiftUI` tracking paradigms.

### Removed
- The requirement to manually call `applicationDidFinishLaunching()` and `applicationWillTerminate()` from the `AppDelegate`.

## [1.0.3] - 2025-08-09

### Added
- Initial SDK setup
- Integration with CocoaLumberjack
- Integration with Swift-log
- Basic logging functionality with multiple log levels
- SwiftLint integration for code quality
- Screen loading time tracking feature
  - Automatic tracking of view controller loading times
  - Configurable warning threshold for slow loading
  - Detailed metadata including screen name and duration
- Shake-to-share logs functionality
  - Configurable share dialog
  - Support for both iPhone and iPad
  - Thread-safe implementation
- Environment-based configuration
  - Predefined configurations for development, staging, and production
  - Persistent environment settings
  - Custom environment support
  - Environment-specific log formats and thresholds
- Memory leak detection
  - Automatic detection of retained view controllers
  - Object lifecycle monitoring
  - Detailed memory analysis logs
  - Environment-specific configuration
  - Thread-safe implementation
  - Customizable check intervals
- Async/await support (iOS 13.0+)
  - Async logging methods
  - Async configuration
  - Async file management
  - Async memory leak detection
  - Async screen time tracking
  - Full backward compatibility
- Enhanced metadata support
  - Support for objects as metadata values
  - Automatic object serialization
  - CustomStringConvertible integration
  - Foundation object support
  - Collection type support
  - Error object support