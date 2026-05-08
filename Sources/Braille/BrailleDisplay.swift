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
    /// Send text to the display. Translation to dot patterns is performed
    /// by the underlying transport (e.g. the BRLTTY daemon's configured
    /// text/contraction tables).
    func write(text: String) async throws
}

extension BrailleDisplay {
    public func connect() async throws {}
    public func disconnect() async throws {}
}
