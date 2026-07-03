#if canImport(UIKit)
import UIKit
import EasyLoggingCore

@available(iOS 15.0, *)
public extension EasyLogger {
    /// Asynchronously tracks screen appearance for the given view controller.
    func trackScreenAppearance(_ viewController: UIViewController) async {
        let screenName = String(describing: type(of: viewController))
        await ScreenTimeTracker.shared.trackScreenAppearance(screenName: screenName)
    }

    /// Asynchronously ends screen tracking and returns the duration.
    func endScreenTracking(_ viewController: UIViewController) async -> TimeInterval? {
        await finishScreenTracking(
            screenName: String(describing: type(of: viewController)),
            trackingMethod: nil
        )
    }

    /// Asynchronously clears all screen time tracking data.
    func clearScreenTracking() async {
        await ScreenTimeTracker.shared.clearTracking()
    }
}
#endif
