//
//  MemoryLeakDetector.swift
//
//
//  Created by Yildirim, Alper on 12.02.2025.
//

#if canImport(UIKit)
import Foundation
import UIKit

/// Detects potential memory leaks in view controllers and other objects.
/// Uses structured concurrency with `Task` instead of Timer + RunLoop.
final class MemoryLeakDetector {
    private var weakTargets: [WeakTargetContainer] = []
    private let lock = UnfairLock()
    private let checkInterval: TimeInterval
    private var monitoringTask: Task<Void, Never>?
    private weak var logger: EasyLogger?

    /// Container for weak references to monitored objects
    private class WeakTargetContainer {
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

        monitoringTask = Task.detached { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(self.checkInterval * 1_000_000_000))
                guard !Task.isCancelled else { break }
                self.checkForLeaks()
            }
        }
    }

    /// Stop monitoring for memory leaks
    func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
        lock.withLock { weakTargets.removeAll() }
    }

    /// Add an object to be monitored for memory leaks
    func addTarget(_ target: AnyObject, identifier: String? = nil) {
        let actualIdentifier = identifier ?? String(describing: type(of: target))
        let container = WeakTargetContainer(target: target, identifier: actualIdentifier)
        lock.withLock { weakTargets.append(container) }

        logger?.internalDebug(LoggingConstants.MemoryLeakMessage.started, metadata: [
            LoggingConstants.MetadataKey.objectType: actualIdentifier,
            LoggingConstants.MetadataKey.address: String(describing: Unmanaged.passUnretained(target).toOpaque())
        ])
    }

    /// Remove an object from monitoring
    func removeTarget(_ target: AnyObject) {
        lock.withLock {
            weakTargets.removeAll { $0.target === target }
        }
    }

    /// Check for potential memory leaks
    private func checkForLeaks() {
        let currentDate = Date()
        var detectedLeaks = false

        lock.withLock {
            // Remove deallocated objects, check remaining ones
            weakTargets = weakTargets.filter { container in
                guard let target = container.target else { return false }

                let lifetime = currentDate.timeIntervalSince(container.creationDate)

                if let viewController = target as? UIViewController {
                    DispatchQueue.main.async { [weak self] in
                        self?.checkViewControllerLeak(
                            viewController: viewController,
                            container: container,
                            lifetime: lifetime,
                            currentDate: currentDate
                        )
                    }
                } else if lifetime > LoggingConstants.TimeInterval.objectLeakThreshold {
                    if container.lastWarningDate.map({ currentDate.timeIntervalSince($0) > LoggingConstants.TimeInterval.leakWarningInterval }) ?? true {
                        container.lastWarningDate = currentDate
                        self.logLeak(target: target, identifier: container.identifier, lifetime: lifetime)
                        detectedLeaks = true
                    }
                }

                return true
            }
        }

        if detectedLeaks {
            logger?.internalWarning(LoggingConstants.MemoryLeakMessage.multipleDetected)
        }
    }

    /// Check if a UIViewController is leaked (called on main thread)
    @MainActor
    private func checkViewControllerLeak(
        viewController: UIViewController,
        container: WeakTargetContainer,
        lifetime: TimeInterval,
        currentDate: Date
    ) {
        let isPresenting = viewController.isBeingPresented
        let isDismissing = viewController.isBeingDismissed
        let isMovingToParent = viewController.isMovingToParent
        let isMovingFromParent = viewController.isMovingFromParent
        let hasParent = viewController.parent != nil
        let hasPresentingVC = viewController.presentingViewController != nil
        let hasWindow = viewController.view.window != nil

        if !isPresenting &&
           !isDismissing &&
           !isMovingToParent &&
           !isMovingFromParent &&
           !hasParent &&
           !hasPresentingVC &&
           !hasWindow &&
           lifetime > LoggingConstants.TimeInterval.viewControllerLeakThreshold {

            if container.lastWarningDate.map({ currentDate.timeIntervalSince($0) > LoggingConstants.TimeInterval.leakWarningInterval }) ?? true {
                container.lastWarningDate = currentDate
                logLeak(target: viewController, identifier: container.identifier, lifetime: lifetime)
                logger?.internalWarning(LoggingConstants.MemoryLeakMessage.multipleDetected)
            }
        }
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
            DispatchQueue.main.async { [weak self] in
                let additionalMetadata: [String: Any] = [
                    LoggingConstants.MetadataKey.parent: String(describing: viewController.parent),
                    LoggingConstants.MetadataKey.presenting: String(describing: viewController.presentingViewController),
                    LoggingConstants.MetadataKey.presented: String(describing: viewController.presentedViewController),
                    LoggingConstants.MetadataKey.hasWindow: String(viewController.view.window != nil)
                ]
                self?.logger?.internalDebug(LoggingConstants.MemoryLeakMessage.viewControllerDetails, metadata: additionalMetadata)
            }
        }
    }
}
#endif
