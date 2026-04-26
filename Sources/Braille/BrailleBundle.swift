//
//  BrailleBundle.swift
//
//  Copyright © 2026 Doug Russell. All rights reserved.
//

import Foundation

/// Returns the path to the liblouis tables bundled with the Braille module,
/// or nil if the tables resource directory is absent (e.g. during local dev
/// without a full resource bundle).
func brlapiFrameworkTablesPath() -> String? {
    // resourceURL is non-nil for macOS versioned bundles (Xcode app builds);
    // flat SPM CLI bundles leave it nil, so fall back to bundleURL.
    let base = Bundle.module.resourceURL ?? Bundle.module.bundleURL
    let url = base.appendingPathComponent("tables")
    return FileManager.default.fileExists(atPath: url.path) ? url.path : nil
}
