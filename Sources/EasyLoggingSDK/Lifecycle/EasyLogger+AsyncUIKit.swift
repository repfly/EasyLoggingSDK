#if canImport(UIKit)
import UIKit

@available(iOS 15.0, *)
public extension EasyLogger {
    /// Asynchronously tracks screen appearance
    func trackScreenAppearanceAsync(_ viewController: UIViewController) async {
        let screenName = String(describing: type(of: viewController))
        await screenTimeTracker.trackScreenAppearance(screenName: screenName)
    }

    /// Asynchronously ends screen tracking and returns the duration
    func endScreenTrackingAsync(_ viewController: UIViewController) async -> TimeInterval? {
        await finishScreenTracking(
            screenName: String(describing: type(of: viewController)),
            trackingMethod: nil
        )
    }

    /// Asynchronously clears all screen time tracking data
    func clearScreenTrackingAsync() async {
        await screenTimeTracker.clearTracking()
    }
}
#endif
