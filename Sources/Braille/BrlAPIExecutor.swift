//
//  BrlAPIExecutor.swift
//
//  Copyright © 2026 Doug Russell. All rights reserved.
//

import Foundation

final class BrlAPIExecutor: SerialExecutor, @unchecked Sendable {
    private let queue = DispatchQueue(
        label: "BrlAPI",
        target: .global()
    )

    func enqueue(_ job: UnownedJob) {
        queue.async {
            job.runSynchronously(on: self.asUnownedSerialExecutor())
        }
    }

    func asUnownedSerialExecutor() -> UnownedSerialExecutor {
        UnownedSerialExecutor(ordinary: self)
    }
}
