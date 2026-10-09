// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MSXPET",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MSXPET", targets: ["MSXPET"])
    ],
    targets: [
        .executableTarget(
            name: "MSXPET",
            path: "Sources/MSXPET",
            resources: [
                .copy("Resources")
            ]
        ),
        .testTarget(
            name: "MSXPETTests",
            dependencies: ["MSXPET"],
            path: "Tests/MSXPETTests"
        )
    ]
)
