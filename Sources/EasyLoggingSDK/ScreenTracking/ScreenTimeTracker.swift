//
//  ScreenTimeTracker.swift
//
//
//  Created by Yildirim, Alper on 12.02.2025.
//

import Foundation
import QuartzCore

/// Actor-based helper to track screen loading times for both UIKit and SwiftUI.
/// Actor isolation eliminates the async-write/sync-read race condition that existed
/// with the previous DispatchQueue-based implementation.
actor ScreenTimeTracker {

    private var screenTimings: [String: CFTimeInterval] = [:]

    /// Start tracking time for a screen.
    func trackScreenAppearance(screenName: String) {
        screenTimings[screenName] = CACurrentMediaTime()
    }

    /// End tracking time for a screen and return the duration.
    func endScreenTracking(screenName: String) -> TimeInterval? {
        guard let startTime = screenTimings[screenName] else { return nil }
        screenTimings.removeValue(forKey: screenName)
        return CACurrentMediaTime() - startTime
    }

    /// Clear all tracked timings.
    func clearTracking() {
        screenTimings.removeAll()
    }
}
