// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BusyBar",
    platforms: [.macOS(.v14), .iOS(.v17), .tvOS(.v17), .watchOS(.v10), .visionOS(.v1)],
    products: [
        .library(name: "BusyBar", targets: ["BusyBar"])
    ],
    targets: [
        .target(name: "BusyBar"),
        .testTarget(name: "BusyBarTests", dependencies: ["BusyBar"]),
    ]
)
