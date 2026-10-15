// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "gamepads_darwin",
    platforms: [
        .iOS("13.0"),
        .macOS("10.15")
    ],
    products: [
        .library(name: "gamepads-darwin", targets: ["gamepads_darwin"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "gamepads_darwin",
            dependencies: [],
            linkerSettings: [
                .linkedFramework("GameController"),
                .linkedFramework("IOKit", .when(platforms: [.macOS]))
            ]
        )
    ]
)
