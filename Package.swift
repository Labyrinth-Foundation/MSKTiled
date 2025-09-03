// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MSKTiled",
    products: [
        .library(
            name: "MSKTiled",
            targets: ["MSKTiled"]),
    ],
    dependencies: [
        // no external dependencies
    ],
    targets: [
        .target(
            name: "MSKTiled"
        ),
        .testTarget(
            name: "MSKTiledTests",
            dependencies: ["MSKTiled"]),
    ]
)
