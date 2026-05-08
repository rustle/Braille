//
//  BrlAPIDisplay.swift
//
//  Copyright © 2026 Doug Russell. All rights reserved.
//

import BrlAPI
import Darwin
import Foundation

/// BrailleDisplay implementation backed by a running BRLTTY daemon via BrlAPI.
///
/// Call `connect()` to open a connection and enter tty mode, then use
/// `write(cells:)` to push dot patterns. Call `disconnect()` when done.
public actor BrlAPIDisplay: BrailleDisplay {
    public nonisolated let unownedExecutor: UnownedSerialExecutor
    private let executor: BrlAPIExecutor

    public private(set) var cellCount: Int = 0
    // Heap-allocated handle owned by this actor. nil after disconnect().
    // brlapi_handle_t is an incomplete C type; Swift imports brlapi_handle_t *
    // as OpaquePointer.
    private var handle: OpaquePointer?

    public init() {
        let executor = BrlAPIExecutor()
        self.executor = executor
        self.unownedExecutor = executor.asUnownedSerialExecutor()
    }

    public func connect() throws {
        let handleSize = brlapi_getHandleSize()
        guard let raw = malloc(handleSize) else {
            throw BrlAPIError.connectionFailed("malloc failed")
        }
        let handle = OpaquePointer(raw)

        var settings = brlapi_connectionSettings_t(auth: nil, host: nil)
        guard brlapi__openConnection(handle, &settings, nil) >= 0 else {
            let msg = brlapiErrorString()
            free(raw)
            throw BrlAPIError.connectionFailed(msg)
        }

        var x: UInt32 = 0
        var y: UInt32 = 0
        guard brlapi__getDisplaySize(handle, &x, &y) == 0 else {
            let msg = brlapiErrorString()
            brlapi__closeConnection(handle)
            free(raw)
            throw BrlAPIError.getDisplaySizeFailed(msg)
        }

        // Pass an empty tty path (count=0) to enter the root of the tty tree.
        // BRLAPI_TTY_DEFAULT (-1) auto-detects the current tty, which fails for
        // GUI apps that have no controlling terminal.
        guard brlapi__enterTtyModeWithPath(handle, nil, 0, nil) >= 0 else {
            let msg = brlapiErrorString()
            brlapi__closeConnection(handle)
            free(raw)
            throw BrlAPIError.enterTtyModeFailed(msg)
        }

        self.cellCount = Int(x * y)
        self.handle = handle
    }

    public func disconnect() {
        guard let h = handle else { return }
        brlapi__leaveTtyMode(h)
        brlapi__closeConnection(h)
        free(UnsafeMutableRawPointer(h)!)
        handle = nil
    }

    public func write(text: String) throws {
        guard let h = handle else { throw BrlAPIError.notConnected }
        // wchar_t is 32-bit on Darwin; map UnicodeScalar values directly
        // and append the null terminator.
        var buffer: [wchar_t] = text.unicodeScalars.map {
            wchar_t(bitPattern: $0.value)
        }
        buffer.append(0)
        let result = buffer.withUnsafeBufferPointer { ptr in
            brlapi__writeWText(h, BRLAPI_CURSOR_OFF, ptr.baseAddress)
        }
        guard result == 0 else {
            throw BrlAPIError.writeFailed(brlapiErrorString())
        }
    }
}

/// Reads the thread-local brlapi_error and returns its human-readable description.
/// Must be called on the same thread immediately after a failed brlapi__ call.
private func brlapiErrorString() -> String {
    guard let loc = brlapi_error_location(),
          let cstr = brlapi_strerror(loc) else {
        return "unknown BrlAPI error"
    }
    return String(cString: cstr)
}

public enum BrlAPIError: Error {
    case connectionFailed(String)
    case getDisplaySizeFailed(String)
    case enterTtyModeFailed(String)
    case writeFailed(String)
    case notConnected
}

extension BrlAPIError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .connectionFailed(let msg):      "BrlAPI connection failed: \(msg)"
        case .getDisplaySizeFailed(let msg):  "BrlAPI get display size failed: \(msg)"
        case .enterTtyModeFailed(let msg):    "BrlAPI enter tty mode failed: \(msg)"
        case .writeFailed(let msg):           "BrlAPI write failed: \(msg)"
        case .notConnected:                   "BrlAPI display not connected"
        }
    }
}
