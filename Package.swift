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
            name: "BuildBRLTTY",
            targets: ["BuildBRLTTY"]
        ),
    ],
    targets: [
        .binaryTarget(
            name: "BrlAPI",
            url: "https://github.com/rustle/Braille/releases/download/1.0.4/BrlAPI.xcframework.zip",
            checksum: "97a3056e4a1946532f5da9efaa38dbc3485b6e09f452886e2610dcc0eb2f0924"
        ),
        .target(
            name: "CLiblouis",
            publicHeadersPath: ".",
            cSettings: [
                .define("TABLESDIR", to: "\"\"")
            ]
        ),
        .target(
            name: "Braille",
            dependencies: ["BrlAPI", "CLiblouis"],
            path: ".",
            sources: ["Sources/Braille"],
            resources: [.copy("liblouis/tables")]
        ),
        .testTarget(
            name: "BrailleTests",
            dependencies: ["Braille"]
        ),
        .plugin(
            name: "BuildBRLTTY",
            capability: .command(
                intent: .custom(
                    verb: "build-brltty",
                    description: "Build the BRLTTY daemon and libbrlapi from source"
                ),
                permissions: [
                    .writeToPackageDirectory(
                        reason:
                            "Creates .build/brltty/ containing the compiled BRLTTY daemon and libbrlapi"
                    ),
                    .allowNetworkConnections(
                        scope: .all(ports: []),
                        reason: "Fetches BRLTTY and liblouis submodules if not yet populated"
                    ),
                ]
            )
        ),
    ],
    swiftLanguageModes: [.v6]
)
