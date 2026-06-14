import XCTest
@testable import EasyLoggingSDK

final class ScreenTimeTrackerTests: XCTestCase {

    private var tracker: ScreenTimeTracker!

    override func setUp() {
        super.setUp()
        tracker = ScreenTimeTracker()
    }

    // MARK: - Track and End

    func testTrackAndEnd() async {
        await tracker.trackScreenAppearance(screenName: "TestScreen")
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        let duration = await tracker.endScreenTracking(screenName: "TestScreen")
        XCTAssertNotNil(duration)
        XCTAssertTrue(duration! > 0)
    }

    func testEndWithoutTrackReturnsNil() async {
        let duration = await tracker.endScreenTracking(screenName: "NeverTracked")
        XCTAssertNil(duration)
    }

    func testEndRemovesTracking() async {
        await tracker.trackScreenAppearance(screenName: "TestScreen")
        _ = await tracker.endScreenTracking(screenName: "TestScreen")
        let secondDuration = await tracker.endScreenTracking(screenName: "TestScreen")
        XCTAssertNil(secondDuration)
    }

    // MARK: - Clear Tracking

    func testClearTrackingRemovesAll() async {
        await tracker.trackScreenAppearance(screenName: "Screen1")
        await tracker.trackScreenAppearance(screenName: "Screen2")
        await tracker.clearTracking()

        let duration1 = await tracker.endScreenTracking(screenName: "Screen1")
        let duration2 = await tracker.endScreenTracking(screenName: "Screen2")

        XCTAssertNil(duration1)
        XCTAssertNil(duration2)
    }

    // MARK: - Multiple Screens

    func testMultipleScreensTrackedIndependently() async {
        await tracker.trackScreenAppearance(screenName: "Screen1")
        try? await Task.sleep(nanoseconds: 10_000_000)
        await tracker.trackScreenAppearance(screenName: "Screen2")
        try? await Task.sleep(nanoseconds: 10_000_000)

        let duration1 = await tracker.endScreenTracking(screenName: "Screen1")
        let duration2 = await tracker.endScreenTracking(screenName: "Screen2")

        XCTAssertNotNil(duration1)
        XCTAssertNotNil(duration2)
        XCTAssertTrue(duration1! > duration2!)
    }

    // MARK: - Concurrent Access

    func testConcurrentTrackingDoesNotCrash() async {
        // Bind the Sendable actor to a local so the task closures don't capture the
        // non-Sendable XCTestCase `self` (a Swift 6 sending-closure error otherwise).
        let tracker = tracker!
        await withTaskGroup(of: Void.self) { group in
            for index in 0..<100 {
                group.addTask {
                    await tracker.trackScreenAppearance(screenName: "Screen\(index)")
                }
            }
        }

        await withTaskGroup(of: Void.self) { group in
            for index in 0..<100 {
                group.addTask {
                    _ = await tracker.endScreenTracking(screenName: "Screen\(index)")
                }
            }
        }
    }
}
