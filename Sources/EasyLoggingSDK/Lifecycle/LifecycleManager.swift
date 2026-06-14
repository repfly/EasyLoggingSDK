#if canImport(UIKit)
import Foundation
import UIKit

/// Wires the SDK into the application launch lifecycle. Its sole remaining job is to (re)install
/// shake-to-share once the app has finished launching, so the gesture overlay attaches to a live
/// scene rather than racing the SDK's own initialization.
@MainActor
final class LifecycleManager {
    private let logger: EasyLogger

    init(logger: EasyLogger) {
        self.logger = logger
        setupLifecycleObservers()
    }

    private func setupLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidFinishLaunching),
            name: UIApplication.didFinishLaunchingNotification,
            object: nil
        )
    }

    @objc private func applicationDidFinishLaunching() {
        logger.applicationDidFinishLaunching()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
#endif
