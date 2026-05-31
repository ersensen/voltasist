// swift-tools-version: 5.9
// Package.swift — VoltAsist iOS Uygulaması

import PackageDescription

let package = Package(
    name: "VoltAsist",
    platforms: [
        .iOS(.v17)           // iOS 17+ zorunlu (Charts, NavigationStack için)
    ],
    products: [
        .library(
            name: "VoltAsist",
            targets: ["VoltAsist"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "VoltAsist",
            dependencies: [],
            path: "Sources",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "VoltAsistTests",
            dependencies: ["VoltAsist"],
            path: "Tests"
        )
    ]
)
