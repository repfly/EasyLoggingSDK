#if canImport(UIKit)
import Foundation
import UIKit

/// Manages the SDK's integration with the application lifecycle events.
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

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }

    @objc private func applicationDidFinishLaunching() {
        logger.applicationDidFinishLaunching()
    }

    @objc private func applicationWillTerminate() {
        logger.applicationWillTerminate()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
#endif
