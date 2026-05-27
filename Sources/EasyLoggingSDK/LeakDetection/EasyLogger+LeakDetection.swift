#if canImport(UIKit)

public extension EasyLogger {
    func monitorForLeaks(_ target: AnyObject, identifier: String? = nil) {
        guard self.configuration.enableMemoryLeakDetection else { return }
        Task { await self.memoryLeakDetector.addTarget(target, identifier: identifier) }
    }

    func stopMonitoringForLeaks(_ target: AnyObject) {
        guard self.configuration.enableMemoryLeakDetection else { return }
        Task { await self.memoryLeakDetector.removeTarget(target) }
    }
}
#endif
