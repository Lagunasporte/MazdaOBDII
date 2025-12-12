// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VAGDiagTool",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "VAGOBD",
            targets: ["VAGOBD"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/kkonteh97/SwiftOBD2.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "VAGOBD",
            dependencies: ["SwiftOBD2"],
            path: "Sources/VAGOBD"
        ),
        .testTarget(
            name: "VAGOBDTests",
            dependencies: ["VAGOBD"],
            path: "Tests/VAGOBDTests"
        ),
    ]
)
