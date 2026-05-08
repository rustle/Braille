//
//  MockBrailleDisplayTests.swift
//
//  Copyright © 2026 Doug Russell. All rights reserved.
//

import Testing
@testable import Braille

struct MockBrailleDisplayTests {
    @Test func recordsLastWrittenText() async throws {
        let display = MockBrailleDisplay(cellCount: 40)
        try await display.write(text: "hello")
        let last = await display.lastText
        #expect(last == "hello")
    }
}
