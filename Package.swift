// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "EasyLoggingSDK",
    platforms: [
        .iOS(.v12),
        .macOS(.v10_15),
        .tvOS(.v15),
        .watchOS(.v9),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "EasyLoggingSDK",
            targets: ["EasyLoggingSDK"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/CocoaLumberjack/CocoaLumberjack.git", from: "3.8.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
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
