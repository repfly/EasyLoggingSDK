// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "EasyLoggingSDK",
    // iOS and macOS are the supported platforms. The SDK depends heavily on UIKit, so tvOS/
    // watchOS are deliberately NOT declared (they would be unverified).
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "EasyLoggingSDK",
            targets: ["EasyLoggingSDK"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/CocoaLumberjack/CocoaLumberjack.git", .upToNextMajor(from: "3.8.0")),
        .package(url: "https://github.com/apple/swift-log.git", .upToNextMajor(from: "1.4.0")),
        // Build-tool plugin only: generates DocC documentation. It is NOT linked into the library,
        // so it adds no runtime dependency for consumers of EasyLoggingSDK.
        .package(url: "https://github.com/apple/swift-docc-plugin", .upToNextMajor(from: "1.0.0")),
    ],
    targets: [
        .target(
            name: "EasyLoggingSDK",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "CocoaLumberjack", package: "CocoaLumberjack"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "EasyLoggingSDKTests",
            dependencies: ["EasyLoggingSDK"]
        ),
    ]
)
