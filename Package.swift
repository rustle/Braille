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
            url: "https://github.com/rustle/Braille/releases/download/1.0.4/BrlAPI.xcframework.zip",
            checksum: "97a3056e4a1946532f5da9efaa38dbc3485b6e09f452886e2610dcc0eb2f0924"
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
