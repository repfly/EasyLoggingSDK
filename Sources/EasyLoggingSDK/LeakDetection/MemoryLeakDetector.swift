#if canImport(UIKit)
import Foundation
import UIKit

/// Detects potential memory leaks in view controllers and other objects.
/// Uses actor isolation for thread safety and structured `Task` for periodic checks.
actor MemoryLeakDetector {
    private var weakTargets: [WeakTargetContainer] = []
    private let checkInterval: TimeInterval
    private var monitoringTask: Task<Void, Never>?
    private weak var logger: EasyLogger?

    /// Container for weak references to monitored objects
    private final class WeakTargetContainer {
        weak var target: AnyObject?
        let identifier: String
        let creationDate: Date
        var lastWarningDate: Date?

        init(target: AnyObject, identifier: String) {
            self.target = target
            self.identifier = identifier
            self.creationDate = Date()
        }
    }

    init(logger: EasyLogger, checkInterval: TimeInterval = LoggingConstants.TimeInterval.defaultLeakCheckInterval) {
        self.logger = logger
        self.checkInterval = checkInterval
    }

    /// Start monitoring for memory leaks
    func startMonitoring() {
        stopMonitoring()

        monitoringTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(self.checkInterval * 1_000_000_000))
                guard !Task.isCancelled else { break }
                await self.checkForLeaks()
            }
        }
    }

    /// Stop monitoring for memory leaks
    func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
        weakTargets.removeAll()
    }

    /// Add an object to be monitored for memory leaks
    func addTarget(_ target: AnyObject, identifier: String? = nil) {
        let actualIdentifier = identifier ?? String(describing: type(of: target))
        let container = WeakTargetContainer(target: target, identifier: actualIdentifier)
        weakTargets.append(container)

        logger?.internalDebug(LoggingConstants.MemoryLeakMessage.started, metadata: [
            LoggingConstants.MetadataKey.objectType: actualIdentifier,
            LoggingConstants.MetadataKey.address: String(describing: Unmanaged.passUnretained(target).toOpaque())
        ])
    }

    /// Remove an object from monitoring
    func removeTarget(_ target: AnyObject) {
        weakTargets.removeAll { $0.target === target }
    }

    /// Check for potential memory leaks
    private func checkForLeaks() async {
        let currentDate = Date()
        var detectedLeaks = false

        weakTargets = weakTargets.filter { container in
            guard let target = container.target else { return false }

            let lifetime = currentDate.timeIntervalSince(container.creationDate)

            if target is UIViewController {
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    guard let vc = target as? UIViewController else { return }
                    await self.handleViewControllerLeakCheck(
                        viewController: vc,
                        container: container,
                        lifetime: lifetime,
                        currentDate: currentDate
                    )
                }
            } else if lifetime > LoggingConstants.TimeInterval.objectLeakThreshold {
                if container.lastWarningDate.map({ currentDate.timeIntervalSince($0) > LoggingConstants.TimeInterval.leakWarningInterval }) ?? true {
                    container.lastWarningDate = currentDate
                    logLeak(target: target, identifier: container.identifier, lifetime: lifetime)
                    detectedLeaks = true
                }
            }

            return true
        }

        if detectedLeaks {
            logger?.internalWarning(LoggingConstants.MemoryLeakMessage.multipleDetected)
        }
    }

    /// Process a VC leak check result (called back from MainActor)
    private func handleViewControllerLeakCheck(
        viewController: UIViewController,
        container: WeakTargetContainer,
        lifetime: TimeInterval,
        currentDate: Date
    ) async {
        let isLeaked = await MainActor.run {
            checkViewControllerIsLeaked(viewController: viewController, lifetime: lifetime)
        }

        if isLeaked {
            if container.lastWarningDate.map({ currentDate.timeIntervalSince($0) > LoggingConstants.TimeInterval.leakWarningInterval }) ?? true {
                container.lastWarningDate = currentDate
                logLeak(target: viewController, identifier: container.identifier, lifetime: lifetime)
                logger?.internalWarning(LoggingConstants.MemoryLeakMessage.multipleDetected)
            }
        }
    }

    /// Check if a UIViewController is leaked (must run on MainActor)
    @MainActor
    private func checkViewControllerIsLeaked(
        viewController: UIViewController,
        lifetime: TimeInterval
    ) -> Bool {
        let isPresenting = viewController.isBeingPresented
        let isDismissing = viewController.isBeingDismissed
        let isMovingToParent = viewController.isMovingToParent
        let isMovingFromParent = viewController.isMovingFromParent
        let hasParent = viewController.parent != nil
        let hasPresentingVC = viewController.presentingViewController != nil
        let hasWindow = viewController.view.window != nil

        return !isPresenting &&
               !isDismissing &&
               !isMovingToParent &&
               !isMovingFromParent &&
               !hasParent &&
               !hasPresentingVC &&
               !hasWindow &&
               lifetime > LoggingConstants.TimeInterval.viewControllerLeakThreshold
    }

    private func logLeak(target: AnyObject, identifier: String, lifetime: TimeInterval) {
        let address = String(describing: Unmanaged.passUnretained(target).toOpaque())
        let metadata: [String: Any] = [
            LoggingConstants.MetadataKey.objectType: identifier,
            LoggingConstants.MetadataKey.address: address,
            LoggingConstants.MetadataKey.lifetime: String(format: "%.2f seconds", lifetime),
            LoggingConstants.MetadataKey.memoryAddress: address
        ]

        logger?.internalWarning(LoggingConstants.MemoryLeakMessage.detected, metadata: metadata)

        if let viewController = target as? UIViewController {
            Task { @MainActor [weak self] in
                guard self != nil else { return }
                let additionalMetadata: [String: Any] = [
                    LoggingConstants.MetadataKey.parent: String(describing: viewController.parent),
                    LoggingConstants.MetadataKey.presenting: String(describing: viewController.presentingViewController),
                    LoggingConstants.MetadataKey.presented: String(describing: viewController.presentedViewController),
                    LoggingConstants.MetadataKey.hasWindow: String(viewController.view.window != nil)
                ]
                EasyLogger.shared.internalDebug(LoggingConstants.MemoryLeakMessage.viewControllerDetails, metadata: additionalMetadata)
            }
        }
    }
}
#endif
