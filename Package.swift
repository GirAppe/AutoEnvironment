// swift-tools-version:4.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AutoEnvironment",
    dependencies: [
        .package(url: "https://github.com/tuist/xcodeproj.git", .upToNextMajor(from: "6.5.0")),
        .package(url: "https://github.com/jianstm/Crayon", .upToNextMajor(from: "0.0.1"))
    ],
    targets: [
        .target(
            name: "autoenvironment",
            dependencies: [
                "xcodeproj",
                "Crayon",
        ]),
        .testTarget(
            name: "AutoEnvironmentTests",
            dependencies: [
                "autoenvironment"
        ]),
    ]
)
