//
//  BuildBrlAPI.swift
//
//  Copyright © 2026 Doug Russell. All rights reserved.
//

import Foundation
import PackagePlugin

@main
struct BuildBrlAPI: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) throws {
        let packageDir = context.package.directoryURL.path()
        try run("/usr/bin/git", ["-C", packageDir, "submodule", "update", "--init", "--recursive"])

        if arguments.contains("--xcframework") {
            let script = context.package.directoryURL
                .appending(components: "Scripts", "create-brlapi-xcframework.sh")
                .path()
            var scriptArgs = [script]
            if arguments.contains("--universal") { scriptArgs += ["--universal"] }
            if arguments.contains("--no-clean") { scriptArgs += ["--no-clean"] }
            try run("/bin/bash", scriptArgs)
        } else {
            let script = context.package.directoryURL
                .appending(components: "Scripts", "build-brltty-macos.sh")
                .path()
            var scriptArgs = [script]
            if arguments.contains("--no-clean") { scriptArgs += ["--no-clean"] }
            for arg in arguments where arg.hasPrefix("--arch=") { scriptArgs += [arg] }
            try run("/bin/bash", scriptArgs)
        }
    }

    private func run(_ executable: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw BuildError(executable: executable, exitCode: process.terminationStatus)
        }
    }
}

private struct BuildError: Error, CustomStringConvertible {
    let executable: String
    let exitCode: Int32
    var description: String { "\(executable) exited with code \(exitCode)" }
}
