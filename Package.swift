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
        // NOTE: no `resources:` here on purpose. Declaring resources makes
        // SwiftPM generate a Bundle.module accessor that fatalErrors when
        // its .bundle isn't next to the binary — which silently kills every
        // shipped .app (the bundle only ever exists inside .build/ on the
        // dev machine). The .app gets its Resources from Scripts/build-app.sh
        // instead; lookup order lives in AppResources.bases().
        .executableTarget(
            name: "MSXPET",
            path: "Sources/MSXPET"
        ),
        .testTarget(
            name: "MSXPETTests",
            dependencies: ["MSXPET"],
            path: "Tests/MSXPETTests"
        )
    ]
)
