//
//  BrailleTranslator.swift
//
//  Copyright © 2026 Doug Russell. All rights reserved.
//

import CLiblouis

public struct BrailleTranslator: Sendable {
    public let table: String
    public let displayTable: String

    /// - Parameters:
    ///   - table: Liblouis translation table name or absolute path.
    ///   - displayTable: Liblouis display table name or absolute path.
    ///   - tablesDirectory: Directory containing the liblouis tables. When
    ///     provided, table names are resolved relative to this directory.
    ///     When nil, liblouis uses its built-in search order: the
    ///     `LOUIS_TABLEPATH` environment variable, then `TABLESDIR`.
    public init(
        table: String = "en-nabcc.utb",
        displayTable: String = "text_nabcc.dis",
        tablesDirectory: String? = nil
    ) {
        if let dir = tablesDirectory {
            let base = dir.hasSuffix("/") ? dir : dir + "/"
            self.table = table.hasPrefix("/") ? table : base + table
            self.displayTable = displayTable.hasPrefix("/") ? displayTable : base + displayTable
        } else {
            self.table = table
            self.displayTable = displayTable
        }
    }

    /// Translate text to braille dot patterns. Each byte encodes one cell:
    /// bit N (0-indexed) set means dot N+1 is raised.
    public func translate(_ text: String) -> [UInt8] {
        // liblouis defines widechar as uint16_t regardless of platform wchar_t.
        let inputBuffer = text.unicodeScalars.map { UInt16(truncatingIfNeeded: $0.value) }
        guard !inputBuffer.isEmpty else { return [] }
        var inputLength = Int32(inputBuffer.count)
        var brailleBuffer = [UInt16](repeating: 0, count: inputBuffer.count * 4)
        var brailleLength = Int32(brailleBuffer.count)

        let translateSuccess = table.withCString { tablePtr in
            inputBuffer.withUnsafeBufferPointer { inPtr in
                brailleBuffer.withUnsafeMutableBufferPointer { braillePtr in
                    lou_translateString(
                        tablePtr,
                        inPtr.baseAddress!,
                        &inputLength,
                        braillePtr.baseAddress!,
                        &brailleLength,
                        nil,
                        nil,
                        0
                    )
                }
            }
        }
        guard translateSuccess == 1 else { return [] }

        // Convert braille characters to raw dot patterns using the display table.
        // lou_charToDots sets LOU_DOTS (0x8000) on each output cell; the low byte
        // is the dot pattern (bit N = dot N+1).
        let cellCount = Int(brailleLength)
        var dotsBuffer = [UInt16](repeating: 0, count: cellCount)
        let dotsSuccess = displayTable.withCString { dispPtr in
            brailleBuffer.withUnsafeBufferPointer { braillePtr in
                dotsBuffer.withUnsafeMutableBufferPointer { dotsPtr in
                    lou_charToDots(
                        dispPtr,
                        braillePtr.baseAddress!,
                        dotsPtr.baseAddress!,
                        Int32(cellCount),
                        0
                    )
                }
            }
        }
        guard dotsSuccess == 1 else { return [] }
        return dotsBuffer.map {
            UInt8($0 & 0xFF)
        }
    }
}
