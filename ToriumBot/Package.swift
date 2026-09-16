// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ToriumBot",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .executable(
            name: "ToriumBot",
            targets: ["ToriumBot"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.24.0")
    ],
    targets: [
        .executableTarget(
            name: "ToriumBot",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            path: "ToriumBot",
            exclude: [
                "../Daemon",
                "../Resources"
            ],
            resources: [
                .process("../Resources")
            ]
        )
    ]
)
