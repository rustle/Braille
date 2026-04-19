//
//  BuildBRLTTY.swift
//
//  Copyright © 2026 Doug Russell. All rights reserved.
//

import Foundation
import PackagePlugin

@main
struct BuildBRLTTY: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) throws {
        let packageDir = context.package.directory.string
        try run("/usr/bin/git", ["-C", packageDir, "submodule", "update", "--init", "--recursive"])
        let script = context.package.directory
            .appending("Scripts", "build-brltty-macos.sh")
            .string
        let scriptArgs = arguments.contains("--no-clean") ? [script, "--no-clean"] : [script]
        try run("/bin/bash", scriptArgs)
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
