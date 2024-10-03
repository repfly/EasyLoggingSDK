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
        .package(url: "https://github.com/apple/swift-log.git", from: "1.4.0"),
    ],
    targets: [
        .target(
            name: "EasyLoggingSDK",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "CocoaLumberjack", package: "CocoaLumberjack"),
            ]
        ),
        .testTarget(
            name: "EasyLoggingSDKTests",
            dependencies: ["EasyLoggingSDK"]
        ),
    ]
)
