//
//  StatementInbox.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-08-06.
//

import Foundation
import os

/// File-drop mailbox in the shared App Group container. Member of BOTH the
/// `flymoney` app target and the `flymoneyImport` share extension target —
/// Foundation only, so the extension never links SwiftData or StatementKit.
enum StatementInbox {
    static let appGroupID = "group.com.jheisecke.cashfly"

    /// Test-only seam. The real App Group container needs the entitlement on
    /// the running process, which a unit test host does not carry — tests
    /// scope this to a temp directory instead via `$containerOverride.withValue`.
    /// `nil` (the production default) means "resolve the real container".
    /// `@TaskLocal`, not a plain static var: Swift Testing runs different
    /// suites concurrently, and a plain global would let one suite's override
    /// stomp another's mid-test — task-local storage is scoped to each test's
    /// own task tree, so concurrent suites never see each other's value.
    @TaskLocal static var containerOverride: URL?

    /// `nil` means the App Group entitlement is missing or misconfigured —
    /// never treat that the same as an empty inbox.
    static func containerURL(fileManager: FileManager = .default) -> URL? {
        containerOverride ?? fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    private static func inboxURL(fileManager: FileManager = .default) -> URL? {
        containerURL(fileManager: fileManager)?.appending(path: "Inbox", directoryHint: .isDirectory)
    }

    /// Extension side. Writes `data` as a new PDF and returns its URL.
    @discardableResult
    static func write(_ data: Data, fileManager: FileManager = .default) throws -> URL {
        guard let inbox = inboxURL(fileManager: fileManager) else {
            throw StatementInboxError.missingContainer
        }
        try fileManager.createDirectory(at: inbox, withIntermediateDirectories: true)
        let fileURL = inbox.appending(path: "\(UUID().uuidString).pdf")
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    /// App side. Oldest-first, so files queued before the app is opened replay in order.
    static func pending(fileManager: FileManager = .default) -> [URL] {
        guard let inbox = inboxURL(fileManager: fileManager) else {
            reportMissingContainer()
            return []
        }
        let entries = (try? fileManager.contentsOfDirectory(
            at: inbox, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        return entries.sorted { lhs, rhs in
            modificationDate(of: lhs, fileManager: fileManager) < modificationDate(of: rhs, fileManager: fileManager)
        }
    }

    /// App side. Removes one entry; safe to call on an already-removed URL.
    static func remove(_ url: URL, fileManager: FileManager = .default) {
        try? fileManager.removeItem(at: url)
    }

    /// Backstop against abandoned imports: drops entries older than `maxAge`
    /// and, beyond `maxCount`, the oldest first.
    static func evictStale(
        maxAge: TimeInterval = 7 * 24 * 60 * 60, maxCount: Int = 10, fileManager: FileManager = .default
    ) {
        let entries = pending(fileManager: fileManager)
        let cutoff = Date().addingTimeInterval(-maxAge)
        var survivors: [URL] = []
        for url in entries {
            if modificationDate(of: url, fileManager: fileManager) < cutoff {
                remove(url, fileManager: fileManager)
            } else {
                survivors.append(url)
            }
        }
        if survivors.count > maxCount {
            for url in survivors.prefix(survivors.count - maxCount) {
                remove(url, fileManager: fileManager)
            }
        }
    }

    private static func modificationDate(of url: URL, fileManager: FileManager) -> Date {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey])
        return values?.contentModificationDate ?? .distantPast
    }

    private static let logger = Logger(subsystem: "com.jheisecke.cashfly", category: "StatementInbox")

    /// A missing container must never read as "nothing was shared" — that is
    /// exactly how a broken App Group entitlement looks from the app side.
    /// Debug crashes loudly; release still leaves a trail.
    private static func reportMissingContainer() {
        assertionFailure("StatementInbox: App Group container unavailable — check the com.apple.security.application-groups entitlement, this is not an empty inbox.")
        logger.error("StatementInbox: App Group container unavailable — check the com.apple.security.application-groups entitlement.")
    }
}

enum StatementInboxError: Error, Equatable {
    case missingContainer
}
