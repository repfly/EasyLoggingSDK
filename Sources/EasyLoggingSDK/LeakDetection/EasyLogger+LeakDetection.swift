//
//  EasyLogger+LeakDetection.swift
//
//

#if canImport(UIKit)

public extension EasyLogger {
    func monitorForLeaks(_ target: AnyObject, identifier: String? = nil) {
        guard self.configuration.enableMemoryLeakDetection else { return }
        self.memoryLeakDetector.addTarget(target, identifier: identifier)
    }

    func stopMonitoringForLeaks(_ target: AnyObject) {
        guard self.configuration.enableMemoryLeakDetection else { return }
        self.memoryLeakDetector.removeTarget(target)
    }
}
#endif
