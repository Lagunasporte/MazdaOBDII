// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RX8DiagTool",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "RX8OBD",
            targets: ["RX8OBD"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/kkonteh97/SwiftOBD2.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "RX8OBD",
            dependencies: ["SwiftOBD2"],
            path: "Sources/RX8OBD"
        ),
        .testTarget(
            name: "RX8OBDTests",
            dependencies: ["RX8OBD"],
            path: "Tests/RX8OBDTests"
        ),
    ]
)
