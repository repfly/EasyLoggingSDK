// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "EasyLoggingSDK",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(name: "EasyLoggingSDK", targets: ["EasyLoggingSDK"]),
        .library(name: "EasyLoggingCore", targets: ["EasyLoggingCore"]),
        .library(name: "EasyLoggingNetwork", targets: ["EasyLoggingNetwork"]),
        .library(name: "EasyLoggingUI", targets: ["EasyLoggingUI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/CocoaLumberjack/CocoaLumberjack.git", .upToNextMajor(from: "3.8.0")),
        .package(url: "https://github.com/apple/swift-log.git", .upToNextMajor(from: "1.4.0")),
        .package(url: "https://github.com/apple/swift-docc-plugin", .upToNextMajor(from: "1.0.0")),
    ],
    targets: [
        .target(
            name: "EasyLoggingCore",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "CocoaLumberjack", package: "CocoaLumberjack"),
            ]
        ),
        .target(
            name: "EasyLoggingNetwork",
            dependencies: ["EasyLoggingCore"]
        ),

        .target(
            name: "EasyLoggingUI",
            dependencies: ["EasyLoggingCore", "EasyLoggingNetwork"]
        ),
        .target(
            name: "EasyLoggingSDK",
            dependencies: ["EasyLoggingCore", "EasyLoggingNetwork", "EasyLoggingUI"]
        ),
        .testTarget(
            name: "EasyLoggingSDKTests",
            dependencies: [
                "EasyLoggingSDK",
                "EasyLoggingCore",
                "EasyLoggingNetwork",
                "EasyLoggingUI",
            ]
        ),
    ]
)
