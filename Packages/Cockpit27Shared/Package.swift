// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Cockpit27Shared",
    platforms: [.visionOS(.v2)],
    products: [
        .library(
            name: "Cockpit27Shared",
            targets: ["Cockpit27Shared"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Cockpit27Shared",
            dependencies: [])
    ]
)