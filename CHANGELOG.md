# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

### Changed
- None

### Deprecated
- None

### Removed
- None

### Fixed
- None

### Security
- None 