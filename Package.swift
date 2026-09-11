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
    traits: [
        .trait(
            name: "EnableWebP",
            description: "Enables WebP read/write support via the system libwebp. Requires libwebp (brew install webp on macOS, apt install libwebp-dev on Debian/Ubuntu)."),
        .trait(
            name: "EnableTIFF",
            description: "Enables TIFF/GeoTIFF read/write support via the system libtiff. Requires libtiff (brew install libtiff on macOS, apt install libtiff-dev on Debian/Ubuntu)."),
    ],
    targets: [
        .systemLibrary(
            name: "CLibTIFF",
            pkgConfig: "libtiff-4",
            providers: [
                .brew(["libtiff"]),
                .apt(["libtiff-dev"]),
            ]),
        .target(
            name: "CTIFF",
            dependencies: ["CLibTIFF"],
            cSettings: [
                .define("ENABLE_TIFF", .when(traits: ["EnableTIFF"])),
            ]),
        .systemLibrary(
            name: "CWebP",
            pkgConfig: "libwebp",
            providers: [
                .brew(["webp"]),
                .apt(["libwebp-dev"]),
            ]),
        .target(
            name: "CSTBImage",
            linkerSettings: [
                .linkedLibrary("z"),
            ]),
        .target(
            name: "STBImage",
            dependencies: [
                "CSTBImage",
                .target(name: "CWebP", condition: .when(traits: ["EnableWebP"])),
                .target(name: "CTIFF", condition: .when(traits: ["EnableTIFF"])),
            ]),
        .testTarget(
            name: "STBImageTests",
            dependencies: ["STBImage"]),
    ])
