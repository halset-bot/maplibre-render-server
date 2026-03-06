// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "maplibre-render-server",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.92.0"),
    ],
    targets: [
        // Library — all app logic; imported by Run and AppTests
        .target(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
            ],
            path: "Sources/App"
        ),
        // Executable — thin entrypoint only
        .executableTarget(
            name: "Run",
            dependencies: [
                .target(name: "App"),
            ],
            path: "Sources/Run"
        ),
        // Tests
        .testTarget(
            name: "AppTests",
            dependencies: [
                .target(name: "App"),
                .product(name: "VaporTesting", package: "vapor"),
            ],
            path: "Tests/AppTests"
        ),
    ]
)
