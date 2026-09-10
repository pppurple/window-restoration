// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "WindowRestoration",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "WindowRestorationCore", targets: ["WindowRestorationCore"]),
        .executable(name: "WindowRestoration", targets: ["WindowRestoration"])
    ],
    targets: [
        .target(name: "WindowRestorationCore"),
        .executableTarget(
            name: "WindowRestoration",
            dependencies: ["WindowRestorationCore"]
        ),
        .testTarget(
            name: "WindowRestorationCoreTests",
            dependencies: ["WindowRestorationCore"]
        )
    ]
)
