// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Braille",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Braille",
            targets: ["Braille"]
        ),
        .plugin(
            name: "BuildBrlAPI",
            targets: ["BuildBrlAPI"]
        ),
    ],
    targets: [
        .binaryTarget(
            name: "BrlAPI",
            url: "https://github.com/rustle/Braille/releases/download/1.0.5/BrlAPI.xcframework.zip",
            checksum: "24e9adc541e426fb5bef9de7a7e5fe4d6a7b069d0a5c4a4903e4730d2b39dcd7"
        ),
        .target(
            name: "Braille",
            dependencies: ["BrlAPI"]
        ),
        .testTarget(
            name: "BrailleTests",
            dependencies: ["Braille"]
        ),
        .plugin(
            name: "BuildBrlAPI",
            capability: .command(
                intent: .custom(
                    verb: "build-brlapi",
                    description: "Build the BRLTTY daemon and BrlAPI.xcframework from source"
                ),
                permissions: [
                    .writeToPackageDirectory(
                        reason:
                            "Creates .build/brltty/ containing the compiled BRLTTY daemon and libbrlapi, and BrlAPI.xcframework at the package root"
                    ),
                    .allowNetworkConnections(
                        scope: .all(ports: []),
                        reason: "Fetches the BRLTTY submodule if not yet populated"
                    ),
                ]
            )
        ),
    ],
    swiftLanguageModes: [.v6]
)
