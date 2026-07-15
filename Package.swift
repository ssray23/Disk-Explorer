// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DiskExplorer",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "DiskExplorer", targets: ["DiskExplorer"])
    ],
    targets: [
        .executableTarget(
            name: "DiskExplorer"
        ),
        .testTarget(
            name: "DiskExplorerTests",
            dependencies: ["DiskExplorer"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
