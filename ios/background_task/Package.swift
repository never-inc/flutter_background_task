// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "background_task",
    platforms: [
        .iOS("13.0"),
    ],
    products: [
        .library(name: "background-task", targets: ["background_task"]),
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
    ],
    targets: [
        .target(
            name: "background_task",
            dependencies: [
                .product(name: "Flutter", package: "FlutterFramework"),
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy"),
            ]
        ),
    ]
)
