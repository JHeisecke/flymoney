//
//  StatementInboxTests.swift
//  flymoneyTests
//
//  Created by Javier Heisecke on 2026-08-06.
//

import Foundation
import Testing
@testable import flymoney

@Suite("StatementInbox")
struct StatementInboxTests {

	/// Scopes `StatementInbox.containerOverride` to a temp directory for the
	/// duration of `body`, via the task-local's own `withValue` — not a plain
	/// assignment, so concurrently-running suites never see each other's value.
	private func withTempContainer(_ body: () async throws -> Void) async rethrows {
		let root = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		defer { try? FileManager.default.removeItem(at: root) }
		try await StatementInbox.$containerOverride.withValue(root) {
			try await body()
		}
	}

	@Test("a written file is returned by pending")
	func writeIsReturnedByPending() async throws {
		try await withTempContainer {
			let url = try StatementInbox.write(Data("pdf-bytes".utf8))
			#expect(StatementInbox.pending() == [url])
			#expect(try Data(contentsOf: url) == Data("pdf-bytes".utf8))
		}
	}

	@Test("remove empties the inbox")
	func removeEmptiesInbox() async throws {
		try await withTempContainer {
			let url = try StatementInbox.write(Data("pdf-bytes".utf8))
			StatementInbox.remove(url)
			#expect(StatementInbox.pending().isEmpty)
		}
	}

	@Test("removing an already-removed entry does not throw")
	func removeAlreadyRemovedDoesNotThrow() async throws {
		try await withTempContainer {
			let url = try StatementInbox.write(Data("pdf-bytes".utf8))
			StatementInbox.remove(url)
			StatementInbox.remove(url) // second call must not throw/crash
		}
	}

	@Test("two writes come back oldest-first")
	func twoWritesComeBackOldestFirst() async throws {
		try await withTempContainer {
			let first = try StatementInbox.write(Data("first".utf8))
			// Filesystem modification-date resolution can coincide within a
			// single test run; force a detectable ordering.
			try await Task.sleep(for: .milliseconds(10))
			let second = try StatementInbox.write(Data("second".utf8))
			#expect(StatementInbox.pending() == [first, second])
		}
	}

	@Test("evictStale drops entries past maxCount, oldest first")
	func evictStaleDropsBeyondMaxCount() async throws {
		try await withTempContainer {
			var written: [URL] = []
			for i in 0..<5 {
				written.append(try StatementInbox.write(Data("\(i)".utf8)))
				try await Task.sleep(for: .milliseconds(5))
			}
			StatementInbox.evictStale(maxAge: 999, maxCount: 2)
			#expect(StatementInbox.pending() == Array(written.suffix(2)))
		}
	}

	@Test("evictStale drops entries past maxAge")
	func evictStaleDropsPastMaxAge() async throws {
		try await withTempContainer {
			let url = try StatementInbox.write(Data("stale".utf8))
			StatementInbox.evictStale(maxAge: 0, maxCount: 10)
			#expect(StatementInbox.pending().isEmpty)
			#expect(!FileManager.default.fileExists(atPath: url.path))
		}
	}

	@Test("missing container surfaces as an error, not an empty inbox")
	func missingContainerIsAnError() {
		let fileManager = FileManager.default
		// No override set — the real entitlement is absent in the test host,
		// so the real lookup returns nil here too. This asserts write()
		// distinguishes "misconfigured" from "empty" by throwing rather than
		// silently no-op.
		if StatementInbox.containerURL(fileManager: fileManager) == nil {
			#expect(throws: StatementInboxError.missingContainer) {
				_ = try StatementInbox.write(Data("x".utf8))
			}
		}
	}
}
