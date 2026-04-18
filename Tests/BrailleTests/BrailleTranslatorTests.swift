//
//  BrailleTranslatorTests.swift
//
//  Copyright © 2026 Doug Russell. All rights reserved.
//

import Testing
@testable import Braille

struct BrailleTranslatorTests {
    let translator = BrailleTranslator()

    @Test func translateASCIILetter() {
        // 'a' in 6-dot NABCC = dot 1 only = 0x01
        let cells = translator.translate("a")
        #expect(cells.count == 1)
        #expect(cells[0] == 0x01)
    }

    @Test func translateProducesOneCellPerCharacter() {
        let text = "hello"
        let cells = translator.translate(text)
        #expect(cells.count == text.count)
    }

    @Test func emptyStringProducesNoCells() {
        #expect(translator.translate("").isEmpty)
    }

    @Test func mockDisplayTruncatesToCellCount() async throws {
        let display = MockBrailleDisplay(cellCount: 4)
        try await display.write(cells: [1, 2, 3, 4, 5, 6])
        let last = await display.lastCells
        #expect(last.count == 4)
    }
}
