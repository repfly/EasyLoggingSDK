// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "EasyLoggingSDK",
    platforms: [
        .iOS(.v12)
    ],
    products: [
        .library(
            name: "EasyLoggingSDK",
            targets: ["EasyLoggingSDK"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/CocoaLumberjack/CocoaLumberjack.git", from: "3.8.0"),
    ],
    targets: [
        .target(
            name: "EasyLoggingSDK",
            dependencies: ["CocoaLumberjack"]
        ),
        .testTarget(
            name: "EasyLoggingSDKTests",
            dependencies: ["EasyLoggingSDK"]
        ),
    ]
)
