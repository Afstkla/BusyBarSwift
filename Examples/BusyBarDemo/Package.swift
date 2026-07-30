// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BusyBarDemo",
    platforms: [.macOS(.v14)],
    dependencies: [.package(path: "../..")],
    targets: [
        .executableTarget(
            name: "BusyBarDemo",
            dependencies: [.product(name: "BusyBar", package: "BusyBarSwift")],
            // CoreBluetooth refuses to start without a usage description, and a bare SPM
            // executable has no bundle to put one in — so it goes straight into the binary.
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/BusyBarDemo/Info.plist",
                ])
            ]
        )
    ]
)
