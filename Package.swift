// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BrowserOpener",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "BrowserOpener",
            targets: ["BrowserOpener"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/nalexn/ViewInspector.git", from: "0.9.10")
    ],
    targets: [
        .executableTarget(
            name: "BrowserOpener",
            dependencies: [],
            path: "Sources/BrowserOpener"
        ),
        .testTarget(
            name: "BrowserOpenerTests",
            dependencies: [
                "BrowserOpener",
                .product(name: "ViewInspector", package: "ViewInspector")
            ],
            path: "Tests/BrowserOpenerTests"
        )
    ]
)
