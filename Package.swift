// swift-tools-version: 6.2

import Foundation
import PackageDescription

// MARK: - Build directories

// Resolve the real package root, accounting for SPM's VFS overlay which may
// present #file as "<real_path>/main/Package.swift" during manifest evaluation.
let manifestDir = URL(fileURLWithPath: #file).deletingLastPathComponent()
let root = FileManager.default.fileExists(atPath: manifestDir.path)
    ? manifestDir.path
    : manifestDir.deletingLastPathComponent().path
let brlttyLib = "\(root)/.build/brltty/Programs"

// MARK: - Package definition

let package = Package(
    name: "Braille",
    platforms: [
        .macOS(.v13),
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
        .systemLibrary(name: "CBrlAPI"),
        .target(
            name: "CLiblouis",
            publicHeadersPath: ".",
            cSettings: [
                .define("TABLESDIR", to: "\"\""),
            ]
        ),
        .target(
            name: "Braille",
            dependencies: ["CBrlAPI", "CLiblouis"],
            linkerSettings: {
                var settings: [LinkerSetting] = [.linkedLibrary("brlapi")]
                // Only add the path flags when the directory actually exists on disk.
                // Under Xcode's VFS overlay #file resolves to a synthetic path, so
                // brlttyLib won't exist; Project.xcconfig supplies the paths instead.
                if FileManager.default.fileExists(atPath: brlttyLib) {
                    settings += [
                        .unsafeFlags(["-L\(brlttyLib)", "-Xlinker", "-rpath", "-Xlinker", brlttyLib]),
                    ]
                }
                return settings
            }()
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
                        reason: "Creates .build/brltty/ containing the compiled BRLTTY daemon and libbrlapi"
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
