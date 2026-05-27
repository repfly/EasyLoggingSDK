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

    /// Asynchronously starts monitoring an object for memory leaks
    func monitorForLeaksAsync(_ target: AnyObject, identifier: String? = nil) async {
        guard self.configuration.enableMemoryLeakDetection else { return }
        await memoryLeakDetector.addTarget(target, identifier: identifier)
    }

    /// Asynchronously stops monitoring an object for memory leaks
    func stopMonitoringForLeaksAsync(_ target: AnyObject) async {
        guard self.configuration.enableMemoryLeakDetection else { return }
        await memoryLeakDetector.removeTarget(target)
    }

    /// Asynchronously clears all screen time tracking data
    func clearScreenTrackingAsync() async {
        await screenTimeTracker.clearTracking()
    }
}
#endif
