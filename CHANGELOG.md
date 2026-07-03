# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.0.0]

### Changed
- **Split the package into four products** so consumers only link what they use:
  `EasyLoggingCore` (logging engine, UIKit-free), `EasyLoggingNetwork` (URLProtocol
  interceptor + activity store), `EasyLoggingUI` (in-app viewer, screen tracking,
  shake-to-share), and the `EasyLoggingSDK` umbrella that re-exports all three.
- **UI features no longer self-wire on import.** Call `EasyLoggingSDK.activate()` once at
  launch (or `EasyLoggingUI.install()` in slim builds) to attach the in-app viewer,
  screen tracking, and shake-to-share. Pure logging needs no activation.
- Core is decoupled from the feature layers via the `LogSink` and `EasyLoggerIntegration`
  protocols; feature targets register themselves through `EasyLogger.register(_:)`.
- Adopted the Swift 6 language mode with complete strict-concurrency checking.
- Log delivery is serialized through an actor-backed FIFO pipeline; every public method
  has an `async` overload and `await logger.flush()` guarantees delivery.

### Added
- Structured network capture (`NetworkActivityStore` / `NetworkRequestRecord`) feeding a
  Network tab in the in-app viewer: per-request headers, pretty-printed JSON bodies,
  metrics, and copy-as-cURL. Bodies are captured only outside `.production`.
- Per-key privacy redaction levels (`.auto` / `.always` / `.never`) via
  `LogMetadata.setRedactable(_:forKey:redaction:)`, with automatic redaction of
  sensitive-looking keys on every path.

### Removed
- In-process crash detection. Use MetricKit or a dedicated crash reporter instead
  (see the Getting Started guide for rationale).
