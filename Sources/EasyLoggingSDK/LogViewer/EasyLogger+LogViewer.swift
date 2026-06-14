#if canImport(UIKit)
import UIKit

public extension EasyLogger {
    func showInAppLogViewer() {
        let config = self.configuration
        guard config.enableInAppLogViewer else {
            self.internalWarning(
                "In-app log viewer is not enabled. Enable it in the configuration."
            )
            return
        }
        Task { @MainActor in
            self.logViewer.showLogViewer()
        }
    }

    func clearInAppLogViewerEntries() {
        guard self.configuration.enableInAppLogViewer else { return }
        Task { @MainActor in
            self.logViewer.clearLogs()
        }
    }
}

extension EasyLogger {
    func shareLogFiles(from viewController: UIViewController) {
        Task {
            // Resolve the log files as Sendable URLs on the actor; the non-Sendable DDFileLogger
            // never leaves the actor.
            let logFiles = await self.loggingActor.logFilePaths().map { URL(fileURLWithPath: $0) }
            guard !logFiles.isEmpty else { return }

            await MainActor.run {
                let activityVC = UIActivityViewController(
                    activityItems: logFiles,
                    applicationActivities: nil
                )
                if let popover = activityVC.popoverPresentationController {
                    popover.sourceView = viewController.view
                    popover.sourceRect = CGRect(
                        x: viewController.view.bounds.midX,
                        y: viewController.view.bounds.midY,
                        width: 0,
                        height: 0
                    )
                    popover.permittedArrowDirections = []
                }
                viewController.present(activityVC, animated: true)
            }
        }
    }
}
#endif
