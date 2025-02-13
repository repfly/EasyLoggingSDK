//
//  MemoryLeakDetector.swift
//
//
//  Created by Yildirim, Alper on 12.02.2025.
//

import Foundation
import UIKit

/// A class that helps detect potential memory leaks in view controllers and other objects
final class MemoryLeakDetector {
    private var weakTargets: [WeakTargetContainer] = []
    private let queue = DispatchQueue(label: LoggingConstants.QueueIdentifier.memoryLeakDetector, qos: .utility)
    private let checkInterval: TimeInterval
    private var timer: Timer?
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
        queue.async {
            self.stopMonitoring()
            
            self.timer = Timer.scheduledTimer(
                withTimeInterval: self.checkInterval,
                repeats: true
            ) { [weak self] _ in
                self?.checkForLeaks()
            }
            
            // Keep the timer running in the background
            RunLoop.current.add(self.timer!, forMode: .common)
            RunLoop.current.run()
        }
    }
    
    /// Stop monitoring for memory leaks
    func stopMonitoring() {
        queue.async {
            self.timer?.invalidate()
            self.timer = nil
            self.weakTargets.removeAll()
        }
    }
    
    /// Add an object to be monitored for memory leaks
    /// - Parameters:
    ///   - target: The object to monitor
    ///   - identifier: Optional custom identifier for the object
    func addTarget(_ target: AnyObject, identifier: String? = nil) {
        queue.async {
            // Create a descriptive identifier if none provided
            let actualIdentifier = identifier ?? String(describing: type(of: target))
            
            // Add to monitoring list
            self.weakTargets.append(WeakTargetContainer(
                target: target,
                identifier: actualIdentifier
            ))
            
            // Log the addition
            self.logger?.debug(LoggingConstants.LogMessage.MemoryLeak.started, metadata: [
                LoggingConstants.MetadataKey.objectType: actualIdentifier,
                LoggingConstants.MetadataKey.address: String(format: "%p", unsafeBitCast(target, to: Int.self))
            ])
        }
    }
    
    /// Remove an object from monitoring
    /// - Parameter target: The object to stop monitoring
    func removeTarget(_ target: AnyObject) {
        queue.async {
            self.weakTargets.removeAll { container in
                container.target === target
            }
        }
    }
    
    /// Check for potential memory leaks
    private func checkForLeaks() {
        let currentDate = Date()
        var detectedLeaks = false
        
        // Filter out deallocated objects and check remaining ones
        weakTargets = weakTargets.filter { container in
            guard let target = container.target else { return false }
            
            // Calculate how long the object has existed
            let lifetime = currentDate.timeIntervalSince(container.creationDate)
            
            // Check if this is a view controller that's been dismissed
            if let viewController = target as? UIViewController {
                if !viewController.isBeingPresented && 
                   !viewController.isBeingDismissed && 
                   !viewController.isMovingToParent &&
                   !viewController.isMovingFromParent &&
                   viewController.parent == nil &&
                   viewController.presentingViewController == nil &&
                   viewController.view.window == nil &&
                   lifetime > LoggingConstants.TimeInterval.viewControllerLeakThreshold {
                    
                    // Only log warning once per minute per object
                    if container.lastWarningDate == nil ||
                       currentDate.timeIntervalSince(container.lastWarningDate!) > LoggingConstants.TimeInterval.leakWarningInterval {
                        
                        container.lastWarningDate = currentDate
                        logLeak(target: target, identifier: container.identifier, lifetime: lifetime)
                        detectedLeaks = true
                    }
                }
            }
            // For other objects, check if they've existed longer than expected
            else if lifetime > LoggingConstants.TimeInterval.objectLeakThreshold {
                if container.lastWarningDate == nil ||
                   currentDate.timeIntervalSince(container.lastWarningDate!) > LoggingConstants.TimeInterval.leakWarningInterval {
                    
                    container.lastWarningDate = currentDate
                    logLeak(target: target, identifier: container.identifier, lifetime: lifetime)
                    detectedLeaks = true
                }
            }
            
            return true
        }
        
        if detectedLeaks {
            logger?.warning(LoggingConstants.LogMessage.MemoryLeak.multipleDetected)
        }
    }
    
    private func logLeak(target: AnyObject, identifier: String, lifetime: TimeInterval) {
        let metadata: [String: String] = [
            LoggingConstants.MetadataKey.objectType: identifier,
            LoggingConstants.MetadataKey.address: String(format: "%p", unsafeBitCast(target, to: Int.self)),
            LoggingConstants.MetadataKey.lifetime: String(format: "%.2f seconds", lifetime),
            LoggingConstants.MetadataKey.memoryAddress: String(describing: Unmanaged.passUnretained(target).toOpaque())
        ]
        
        logger?.warning(LoggingConstants.LogMessage.MemoryLeak.detected, metadata: metadata)
        
        // If it's a view controller, log additional information
        if let viewController = target as? UIViewController {
            let additionalMetadata: [String: String] = [
                LoggingConstants.MetadataKey.parent: String(describing: viewController.parent),
                LoggingConstants.MetadataKey.presenting: String(describing: viewController.presentingViewController),
                LoggingConstants.MetadataKey.presented: String(describing: viewController.presentedViewController),
                LoggingConstants.MetadataKey.hasWindow: String(viewController.view.window != nil)
            ]
            logger?.debug(LoggingConstants.LogMessage.MemoryLeak.viewControllerDetails, metadata: additionalMetadata)
        }
    }
} 
