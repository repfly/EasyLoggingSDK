#if canImport(UIKit)
import EasyLoggingCore
import EasyLoggingNetwork
import UIKit

/// Entry point for the UIKit/SwiftUI feature layer; `EasyLoggingSDK.activate()` calls ``install(logger:)``.
public enum EasyLoggingUI {
    @MainActor private static var lifecycleManager: LifecycleManager?

    /// Wires the in-app viewer, screen tracking, and shake-to-share into `logger`. Idempotent.
    @MainActor
    public static func install(logger: EasyLogger = .shared) {
        EasyLoggingNetwork.install(logger: logger)
        logger.register(LogViewerIntegration.shared)
        logger.register(ScreenTrackingIntegration.shared)
        logger.register(ShakeToShareIntegration.shared)

        if lifecycleManager == nil {
            lifecycleManager = LifecycleManager {
                ShakeToShareIntegration.shared.reinstall()
            }
        }
    }
}

@MainActor
final class LogViewerIntegration: EasyLoggerIntegration {
    static let shared = LogViewerIntegration()

    private(set) var viewer: InAppLogViewer?
    private let logger: EasyLogger

    init(logger: EasyLogger = .shared) {
        self.logger = logger
    }

    nonisolated func apply(previous: EasyLogger.Configuration?, new: EasyLogger.Configuration) {
        Task { @MainActor in
            guard new.enableInAppLogViewer || self.viewer != nil else { return }
            let viewer = self.ensureViewer()
            viewer.configure(
                isEnabled: new.enableInAppLogViewer,
                activationGesture: new.logViewerActivationGesture,
                maxLogEntries: new.maxLogViewerEntries
            )
        }
    }

    private func ensureViewer() -> InAppLogViewer {
        if let viewer { return viewer }
        let created = InAppLogViewer(logger: logger)
        viewer = created
        logger.registerLogSink(created)
        return created
    }
}

@MainActor
final class ScreenTrackingIntegration: EasyLoggerIntegration {
    static let shared = ScreenTrackingIntegration()

    nonisolated func apply(previous: EasyLogger.Configuration?, new: EasyLogger.Configuration) {
        let wasEnabled = (previous?.trackScreenLoadingTimes ?? false)
            && (previous?.useAutomaticUIKitScreenTimeTracking ?? false)
        let willBeEnabled = new.trackScreenLoadingTimes && new.useAutomaticUIKitScreenTimeTracking
        guard wasEnabled != willBeEnabled else { return }
        Task { @MainActor in
            if willBeEnabled {
                UIViewController.setupScreenTimeTracking()
            } else {
                UIViewController.tearDownScreenTimeTracking()
            }
        }
    }
}

@MainActor
final class ShakeToShareIntegration: EasyLoggerIntegration {
    static let shared = ShakeToShareIntegration()

    private var handler: ShakeToShareHandler?
    private let logger: EasyLogger

    init(logger: EasyLogger = .shared) {
        self.logger = logger
    }

    nonisolated func apply(previous: EasyLogger.Configuration?, new: EasyLogger.Configuration) {
        Task { @MainActor in self.reinstall() }
    }

    func reinstall() {
        if handler == nil {
            handler = ShakeToShareHandler(logger: logger)
        }
        handler?.setupShakeToShare()
    }
}
#endif
