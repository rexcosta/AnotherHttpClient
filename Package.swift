// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AnotherHttpClient",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "AnotherHttpClient",
            targets: ["AnotherHttpClient"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/rexcosta/AnotherSwiftCommonLib.git",
            .branch("master")
        )
    ],
    targets: [
        .target(
            name: "AnotherHttpClient",
            dependencies: ["AnotherSwiftCommonLib"]
        ),
        .testTarget(
            name: "AnotherHttpClientTests",
            dependencies: ["AnotherHttpClient"]
        ),
    ]
)
