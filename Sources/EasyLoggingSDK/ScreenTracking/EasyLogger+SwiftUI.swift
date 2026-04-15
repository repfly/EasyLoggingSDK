#if canImport(SwiftUI) && canImport(UIKit)
import Foundation
import SwiftUI

// MARK: - SwiftUI Screen Tracking API

public extension EasyLogger {
    /// Start tracking loading time for a SwiftUI screen.
    ///
    /// Call this from the `.onAppear` modifier of your view.
    /// - Parameter screenName: A unique identifier for the screen to track.
    func trackScreenAppearance(name screenName: String) {
        guard self.configuration.trackScreenLoadingTimes else { return }
        Task { await screenTimeTracker.trackScreenAppearance(screenName: screenName) }
    }

    /// End tracking loading time for a SwiftUI screen and log the duration.
    ///
    /// Call this from the `.onDisappear` modifier of your view.
    /// - Parameter screenName: The unique identifier for the screen you started tracking.
    func endScreenTracking(name screenName: String) {
        let config = self.configuration
        guard config.trackScreenLoadingTimes else { return }
        Task {
            guard let duration = await screenTimeTracker.endScreenTracking(
                screenName: screenName
            ) else { return }

            let metadata: [String: Any] = [
                LoggingConstants.MetadataKey.screen: screenName,
                LoggingConstants.MetadataKey.duration: String(format: "%.3f", duration),
                LoggingConstants.MetadataKey.trackingMethod: "swiftui"
            ]

            if duration >= config.slowScreenLoadingThreshold {
                self.internalWarning("Slow screen loading detected", metadata: metadata)
            } else {
                self.internalDebug("Screen loaded", metadata: metadata)
            }
        }
    }
}

// MARK: - SwiftUI View Modifiers

public extension View {
    /// Automatically track screen loading time for this SwiftUI view.
    ///
    /// - Parameter screenName: Custom name for the screen. Required for accurate tracking.
    /// - Returns: The view with screen tracking enabled.
    func trackScreenTime(screenName: String) -> some View {
        modifier(ScreenTimeTrackingModifier(screenName: screenName))
    }

    /// Track screen time with custom metadata.
    ///
    /// - Parameters:
    ///   - screenName: Name for the screen.
    ///   - metadata: Additional metadata to include in logs.
    /// - Returns: The view with enhanced screen tracking.
    func trackScreenTimeWithMetadata<T: Codable>(
        screenName: String,
        metadata: T
    ) -> some View {
        modifier(EnhancedScreenTimeTrackingModifier(screenName: screenName, metadata: metadata))
    }

    /// Track screen time and log screen transitions.
    ///
    /// - Parameter screenName: Name for the screen.
    /// - Returns: The view with transition logging.
    func trackScreenTimeWithTransitions(screenName: String) -> some View {
        modifier(TransitionTrackingModifier(screenName: screenName))
    }
}

// MARK: - View Modifiers (Internal)

private struct ScreenTimeTrackingModifier: ViewModifier {
    let screenName: String

    func body(content: Content) -> some View {
        content
            .onAppear {
                EasyLogger.shared.trackScreenAppearance(name: screenName)
            }
            .onDisappear {
                EasyLogger.shared.endScreenTracking(name: screenName)
            }
    }
}

private struct EnhancedScreenTimeTrackingModifier<T: Codable>: ViewModifier {
    let screenName: String
    let metadata: T

    func body(content: Content) -> some View {
        content
            .onAppear {
                EasyLogger.shared.trackScreenAppearance(name: screenName)
                EasyLogger.shared.internalInfo(
                    "Screen appeared: \(screenName)",
                    metadata: metadata
                )
            }
            .onDisappear {
                EasyLogger.shared.endScreenTracking(name: screenName)
                EasyLogger.shared.internalInfo(
                    "Screen disappeared: \(screenName)",
                    metadata: metadata
                )
            }
    }
}

private struct TransitionTrackingModifier: ViewModifier {
    let screenName: String

    func body(content: Content) -> some View {
        content
            .onAppear {
                EasyLogger.shared.trackScreenAppearance(name: screenName)
                EasyLogger.shared.internalDebug(
                    "Screen transition: \(screenName) appeared"
                )
            }
            .onDisappear {
                EasyLogger.shared.endScreenTracking(name: screenName)
                EasyLogger.shared.internalDebug(
                    "Screen transition: \(screenName) disappeared"
                )
            }
    }
}

#endif
