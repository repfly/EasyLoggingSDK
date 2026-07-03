#if canImport(UIKit)
import UIKit
import EasyLoggingCore

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
            LogViewerIntegration.shared.viewer?.showLogViewer()
        }
    }

    func clearInAppLogViewerEntries() {
        guard self.configuration.enableInAppLogViewer else { return }
        Task { @MainActor in
            LogViewerIntegration.shared.viewer?.clearLogs()
        }
    }
}

extension EasyLogger {
    func shareLogFiles(from viewController: UIViewController) {
        Task {
            let logFiles = await self.getLogFilePaths().map { URL(fileURLWithPath: $0) }
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
