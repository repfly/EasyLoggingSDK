#if canImport(SwiftUI) && canImport(UIKit)
import Foundation
import EasyLoggingCore
import SwiftUI

// MARK: - SwiftUI Screen Tracking API

public extension EasyLogger {
    /// Start tracking loading time for a SwiftUI screen.
    ///
    /// Call this from the `.onAppear` modifier of your view.
    /// - Parameter screenName: A unique identifier for the screen to track.
    func trackScreenAppearance(name screenName: String) {
        guard self.configuration.trackScreenLoadingTimes else { return }
        Task.detached(priority: .utility) {
            await ScreenTimeTracker.shared.trackScreenAppearance(screenName: screenName)
        }
    }

    /// End tracking loading time for a SwiftUI screen and log the duration.
    ///
    /// Call this from the `.onDisappear` modifier of your view.
    /// - Parameter screenName: The unique identifier for the screen you started tracking.
    func endScreenTracking(name screenName: String) {
        Task.detached(priority: .utility) {
            _ = await self.finishScreenTracking(screenName: screenName, trackingMethod: "swiftui")
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

#endif
