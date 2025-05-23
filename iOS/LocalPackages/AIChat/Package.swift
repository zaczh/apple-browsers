// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "AIChat",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "AIChat",
            targets: ["AIChat"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/duckduckgo/DesignResourcesKit", exact: "4.1.0")
    ],
    targets: [
        .target(
            name: "AIChat",
            dependencies: [
                "DesignResourcesKit",
            ],
            resources: [
                .process("Resources/Assets.xcassets")
            ]
        ),
        .testTarget(
            name: "AIChatTests",
            dependencies: ["AIChat"]
        )
    ]
)
