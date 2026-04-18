//
//  BrailleDisplay.swift
//
//  Copyright © 2026 Doug Russell. All rights reserved.
//

public protocol BrailleDisplay: Sendable {
    /// Give display a chance to connect.
    func connect() async throws
    /// Give display a chance to disconnect.
    func disconnect() async throws
    /// Number of cells on the physical display.
    var cellCount: Int { get async }
    /// Write dot patterns to the display. `cells` is truncated to `cellCount` if longer.
    func write(cells: [UInt8]) async throws
}

extension BrailleDisplay {
    public func connect() async throws {}
    public func disconnect() async throws {}
}
