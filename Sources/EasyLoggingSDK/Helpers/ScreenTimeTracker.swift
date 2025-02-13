//
//  ScreenTimeTracker.swift
//
//
//  Created by Yildirim, Alper on 12.02.2025.
//

import Foundation
import UIKit
import QuartzCore

/// Helper class to track screen loading times
final class ScreenTimeTracker {
    private var screenTimings: [String: CFTimeInterval] = [:]
    private let queue = DispatchQueue(
        label: LoggingConstants.QueueIdentifier.screenTracker,
        qos: .utility
    )
    
    /// Start tracking time for a screen
    /// - Parameter viewController: The view controller to track
    func trackScreenAppearance(_ viewController: UIViewController) {
        let screenName = String(describing: type(of: viewController))
        queue.async {
            self.screenTimings[screenName] = CACurrentMediaTime()
        }
    }
    
    /// End tracking time for a screen and return the duration
    /// - Parameter viewController: The view controller to stop tracking
    /// - Returns: Time interval in seconds that the screen took to load
    func endScreenTracking(_ viewController: UIViewController) -> TimeInterval? {
        let screenName = String(describing: type(of: viewController))
        return queue.sync {
            guard let startTime = screenTimings[screenName] else { return nil }
            screenTimings.removeValue(forKey: screenName)
            return CACurrentMediaTime() - startTime
        }
    }
    
    /// Clear all tracked timings
    func clearTracking() {
        queue.async {
            self.screenTimings.removeAll()
        }
    }
} 
