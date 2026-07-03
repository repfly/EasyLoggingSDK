#if canImport(UIKit)
import Foundation
import EasyLoggingCore
import UIKit

/// Wires the SDK into the application launch lifecycle. Its sole remaining job is to (re)install
/// shake-to-share once the app has finished launching, so the gesture overlay attaches to a live
/// scene rather than racing the SDK's own initialization.
@MainActor
final class LifecycleManager {
    private let onDidFinishLaunching: @MainActor () -> Void

    init(onDidFinishLaunching: @escaping @MainActor () -> Void) {
        self.onDidFinishLaunching = onDidFinishLaunching
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
        onDidFinishLaunching()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
#endif
