//
//  EasyLogger+AsyncUIKit.swift
//
//
//  Created by Yildirim, Alper on 19.08.2024.
//

#if canImport(UIKit)
import UIKit

@available(iOS 15.0, *)
public extension EasyLogger {
    /// Asynchronously tracks screen appearance
    func trackScreenAppearanceAsync(_ viewController: UIViewController) async {
        trackScreenAppearance(viewController)
    }

    /// Asynchronously ends screen tracking and returns the duration
    func endScreenTrackingAsync(_ viewController: UIViewController) async -> TimeInterval? {
        await getScreenTrackingDuration(viewController)
    }

    /// Asynchronously starts monitoring an object for memory leaks
    func monitorForLeaksAsync(_ target: AnyObject, identifier: String? = nil) async {
        await withCheckedContinuation { continuation in
            self.performOnInternalQueue {
                self.monitorForLeaks(target, identifier: identifier)
                continuation.resume()
            }
        }
    }

    /// Asynchronously stops monitoring an object for memory leaks
    func stopMonitoringForLeaksAsync(_ target: AnyObject) async {
        await withCheckedContinuation { continuation in
            self.performOnInternalQueue {
                self.stopMonitoringForLeaks(target)
                continuation.resume()
            }
        }
    }

    /// Asynchronously clears all screen time tracking data
    func clearScreenTrackingAsync() async {
        await withCheckedContinuation { continuation in
            self.performOnInternalQueue {
                self.clearScreenTimeTracking()
                continuation.resume()
            }
        }
    }
}
#endif
