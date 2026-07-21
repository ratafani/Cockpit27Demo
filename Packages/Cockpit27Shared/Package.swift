// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Cockpit27Shared",
    platforms: [
        .visionOS(.v2),
        .macOS(.v15),
        .iOS(.v18)
    ],
    products: [
        .library(name: "Cockpit27Shared", targets: ["Cockpit27UI", "Cockpit27Simulation", "Cockpit27Core", "Cockpit27Domain"]),
        .library(name: "Cockpit27Domain", targets: ["Cockpit27Domain"]),
        .library(name: "Cockpit27Core", targets: ["Cockpit27Core"]),
        .library(name: "Cockpit27Simulation", targets: ["Cockpit27Simulation"]),
        .library(name: "Cockpit27UI", targets: ["Cockpit27UI"])
    ],
    dependencies: [
        .package(url: "https://github.com/ratafani/ILSpatial.git", branch: "main"),
        .package(path: "../RealityKitContent")
    ],
    targets: [
        .target(
            name: "Cockpit27Domain",
            dependencies: []
        ),
        .target(
            name: "Cockpit27Core",
            dependencies: ["Cockpit27Domain"]
        ),
        .target(
            name: "Cockpit27Simulation",
            dependencies: [
                "Cockpit27Domain",
                "Cockpit27Core",
                .product(name: "ILSFoundation", package: "ILSpatial"),
                .product(name: "ILSEngine", package: "ILSpatial"),
                .product(name: "ILSHandTracking", package: "ILSpatial"),
                .product(name: "RealityKitContent", package: "RealityKitContent")
            ]
        ),
        .target(
            name: "Cockpit27UI",
            dependencies: [
                "Cockpit27Domain",
                "Cockpit27Core",
                "Cockpit27Simulation",
                .product(name: "ILSFoundation", package: "ILSpatial"),
                .product(name: "ILSEngine", package: "ILSpatial"),
                .product(name: "ILSHandTracking", package: "ILSpatial"),
                .product(name: "RealityKitContent", package: "RealityKitContent")
            ]
        )
    ]
)