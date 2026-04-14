//
//  EasyLogger+ScreenTracking.swift
//
//

#if canImport(UIKit)
import UIKit

public extension EasyLogger {
    func trackScreenAppearance(_ viewController: UIViewController) {
        guard self.configuration.trackScreenLoadingTimes else { return }
        let screenName = String(describing: type(of: viewController))
        Task { await screenTimeTracker.trackScreenAppearance(screenName: screenName) }
    }

    func endScreenTracking(_ viewController: UIViewController) {
        let config = self.configuration
        guard config.trackScreenLoadingTimes else { return }
        let screenName = String(describing: type(of: viewController))
        Task {
            guard let duration = await screenTimeTracker.endScreenTracking(
                screenName: screenName
            ) else { return }
            let metadata: [String: Any] = [
                LoggingConstants.MetadataKey.screen: screenName,
                LoggingConstants.MetadataKey.duration: String(format: "%.3f", duration),
                LoggingConstants.MetadataKey.trackingMethod:
                    config.useAutomaticUIKitScreenTimeTracking ? "automatic" : "manual"
            ]
            if duration >= config.slowScreenLoadingThreshold {
                self.internalWarning("Slow screen loading detected", metadata: metadata)
            } else {
                self.internalDebug("Screen loaded", metadata: metadata)
            }
        }
    }

    func clearScreenTimeTracking() {
        Task { await screenTimeTracker.clearTracking() }
    }
}

extension EasyLogger {
    func getScreenTrackingDuration(
        _ viewController: UIViewController
    ) async -> TimeInterval? {
        let screenName = String(describing: type(of: viewController))
        return await screenTimeTracker.endScreenTracking(screenName: screenName)
    }
}
#endif
