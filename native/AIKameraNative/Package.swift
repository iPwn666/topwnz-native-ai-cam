// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AIKameraNative",
    platforms: [
        .iOS(.v16),
    ],
    products: [
        .library(
            name: "AIKameraNative",
            targets: ["AIKameraNative"]
        ),
    ],
    targets: [
        .target(
            name: "AIKameraNative",
            path: ".",
            exclude: [
                "Package.swift",
                "xtool.yml",
                "Resources/Info.plist",
                "xtool",
            ],
            sources: ["Sources"]
        ),
    ]
)
