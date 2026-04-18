//
//  MockBrailleDisplay.swift
//
//  Copyright © 2026 Doug Russell. All rights reserved.
//

public actor MockBrailleDisplay: BrailleDisplay {
    public nonisolated let cellCount: Int
    public private(set) var lastCells: [UInt8] = []

    public init(cellCount: Int = 40) {
        self.cellCount = cellCount
    }

    public func write(cells: [UInt8]) async throws {
        lastCells = Array(cells.prefix(cellCount))
    }
}
