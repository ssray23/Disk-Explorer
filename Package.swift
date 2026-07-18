// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DiskExplorer",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "DiskExplorer", targets: ["DiskExplorer"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-testing.git", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "DiskExplorer"
        ),
        .testTarget(
            name: "DiskExplorerTests",
            dependencies: [
                "DiskExplorer",
                .product(name: "Testing", package: "swift-testing")
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
