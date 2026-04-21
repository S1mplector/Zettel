// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "Zettel",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "ZettelKit",
            targets: ["ZettelKit"]
        ),
        .executable(
            name: "Zettel",
            targets: ["Zettel"]
        ),
    ],
    targets: [
        .target(
            name: "ZettelKit"
        ),
        .executableTarget(
            name: "Zettel",
            dependencies: ["ZettelKit"]
        ),
        .testTarget(
            name: "ZettelKitTests",
            dependencies: ["ZettelKit"]
        ),
    ]
)
