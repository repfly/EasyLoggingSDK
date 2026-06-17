#if canImport(UIKit)
import UIKit
import EasyLoggingCore

public extension EasyLogger {
    func trackScreenAppearance(_ viewController: UIViewController) {
        guard self.configuration.trackScreenLoadingTimes else { return }
        let screenName = String(describing: type(of: viewController))
        Task.detached(priority: .utility) {
            await ScreenTimeTracker.shared.trackScreenAppearance(screenName: screenName)
        }
    }

    func endScreenTracking(_ viewController: UIViewController) {
        Task.detached(priority: .utility) {
            _ = await self.finishScreenTracking(
                screenName: String(describing: type(of: viewController)),
                trackingMethod: nil
            )
        }
    }

    func clearScreenTimeTracking() {
        Task.detached(priority: .utility) {
            await ScreenTimeTracker.shared.clearTracking()
        }
    }
}

extension EasyLogger {
    func finishScreenTracking(
        screenName: String,
        trackingMethod: String?
    ) async -> TimeInterval? {
        let config = self.configuration
        guard config.trackScreenLoadingTimes else { return nil }

        guard let duration = await ScreenTimeTracker.shared.endScreenTracking(screenName: screenName) else {
            return nil
        }

        let method = trackingMethod ?? (
            config.useAutomaticUIKitScreenTimeTracking ? "automatic" : "manual"
        )

        let metadata: [String: String] = [
            LoggingConstants.MetadataKey.screen: screenName,
            LoggingConstants.MetadataKey.duration: String(format: "%.3f", duration),
            LoggingConstants.MetadataKey.trackingMethod: method
        ]

        if duration >= config.slowScreenLoadingThreshold {
            internalWarning("Slow screen loading detected", metadata: metadata)
        } else {
            internalDebug("Screen loaded", metadata: metadata)
        }

        return duration
    }
}
#endif
