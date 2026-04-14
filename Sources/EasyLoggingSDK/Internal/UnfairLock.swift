//
//  UnfairLock.swift
//
//
//  Created by Claude on behalf of Yildirim, Alper.
//

import os

/// A lightweight lock wrapper around `os_unfair_lock` for low-contention synchronization.
///
/// Wrapped in a class to avoid move-after-use issues with the value-type `os_unfair_lock`.
/// This is the same primitive Apple uses internally and recommends for fast-path reads.
final class UnfairLock: @unchecked Sendable {
    private var _lock = os_unfair_lock()

    func lock() {
        os_unfair_lock_lock(&_lock)
    }

    func unlock() {
        os_unfair_lock_unlock(&_lock)
    }

    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        os_unfair_lock_lock(&_lock)
        defer { os_unfair_lock_unlock(&_lock) }
        return try body()
    }
}
