// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "swift-stb-image",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "STBImage",
            targets: ["STBImage"]),
    ],
    targets: [
        .systemLibrary(
            name: "CWebP",
            pkgConfig: "libwebp",
            providers: [
                .brew(["webp"]),
                .apt(["libwebp-dev"]),
            ]
        ),
        .target(
            name: "CSTBImage",
            linkerSettings: [
                .linkedLibrary("z"),
            ]),
        .target(
            name: "STBImage",
            dependencies: [
                "CSTBImage",
                "CWebP",
            ]),
        .testTarget(
            name: "STBImageTests",
            dependencies: ["STBImage"]),
    ]
)
