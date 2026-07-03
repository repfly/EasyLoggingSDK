import XCTest
@testable import EasyLoggingCore

final class DirectoryHelperTests: XCTestCase {

    func testGetLogDirectoryReturnsValidPath() {
        let path = DirectoryHelper.getLogDirectory()
        XCTAssertFalse(path.isEmpty)
        XCTAssertTrue(path.contains("EasyLoggingSDK"))
    }

    func testGetLogDirectoryCreatesDirectory() {
        let path = DirectoryHelper.getLogDirectory()
        XCTAssertTrue(FileManager.default.fileExists(atPath: path))
    }

    func testGetLogDirectoryIsIdempotent() {
        let path1 = DirectoryHelper.getLogDirectory()
        let path2 = DirectoryHelper.getLogDirectory()
        XCTAssertEqual(path1, path2)
    }
}
