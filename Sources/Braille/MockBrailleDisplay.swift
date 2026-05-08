//
//  MockBrailleDisplay.swift
//
//  Copyright © 2026 Doug Russell. All rights reserved.
//

public actor MockBrailleDisplay: BrailleDisplay {
    public nonisolated let cellCount: Int
    public private(set) var lastText: String = ""

    public init(cellCount: Int = 40) {
        self.cellCount = cellCount
    }

    public func write(text: String) async throws {
        lastText = text
    }
}
