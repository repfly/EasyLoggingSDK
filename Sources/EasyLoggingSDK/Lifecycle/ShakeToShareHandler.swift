#if canImport(UIKit)
import UIKit

/// Handles the 'shake-to-share' functionality.
@MainActor
final class ShakeToShareHandler {
    private let logger: EasyLogger
    private var shakeGestureWindow: UIWindow?

    init(logger: EasyLogger) {
        self.logger = logger
    }

    func setupShakeToShare() {
        guard logger.isShakeToShareEnabled else {
            shakeGestureWindow?.isHidden = true
            shakeGestureWindow = nil
            return
        }

        if shakeGestureWindow == nil {
            let window: ShakeDetectingWindow
            if let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) {
                window = ShakeDetectingWindow(windowScene: scene)
            } else {
                window = ShakeDetectingWindow(frame: .zero)
            }
            window.backgroundColor = .clear
            window.isUserInteractionEnabled = false
            window.windowLevel = .alert
            window.isHidden = false
            window.rootViewController = ShakeDetectingViewController { [weak self] in
                self?.handleShakeGesture()
            }
            self.shakeGestureWindow = window
        }
    }

    private func handleShakeGesture() {
        guard let topViewController = Self.getKeyWindow()?.rootViewController?.topMostViewController else {
            return
        }

        let config = logger.configuration
        let alert = UIAlertController(
            title: config.shareDialogTitle,
            message: config.shareDialogMessage,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Share", style: .default) { [weak self] _ in
            self?.logger.shareLogFiles(from: topViewController)
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        topViewController.present(alert, animated: true)
    }

    private static func getKeyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}

// MARK: - Helper Classes

private final class ShakeDetectingWindow: UIWindow {
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        guard motion == .motionShake else { return }
        (rootViewController as? ShakeDetectingViewController)?.handleShake()
    }
}

private final class ShakeDetectingViewController: UIViewController {
    private let shakeHandler: () -> Void

    init(shakeHandler: @escaping () -> Void) {
        self.shakeHandler = shakeHandler
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func handleShake() {
        shakeHandler()
    }
}
#endif
