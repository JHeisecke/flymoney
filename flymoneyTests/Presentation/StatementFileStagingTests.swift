//
//  StatementFileStagingTests.swift
//  flymoneyTests
//
//  Created by Javier Heisecke on 2026-08-06.
//

import Foundation
import Testing
@testable import flymoney

@Suite("StatementFileStaging")
struct StatementFileStagingTests {

	private func makeSourceFile(contents: Data = Data("fake-pdf-bytes".utf8)) throws -> URL {
		let url = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("pdf")
		try contents.write(to: url)
		return url
	}

	@Test("a copied file is readable and identical to the source")
	func copiedFileIsReadableAndIdentical() throws {
		let contents = Data("hello statement".utf8)
		let source = try makeSourceFile(contents: contents)
		defer { try? FileManager.default.removeItem(at: source) }

		let staged = try StatementFileStaging.stage(source)
		defer { StatementFileStaging.cleanup(staged) }

		#expect(FileManager.default.fileExists(atPath: staged.path))
		#expect(try Data(contentsOf: staged) == contents)
		#expect(staged.pathExtension == "pdf")
	}

	@Test("staged copy is a distinct file from the source, safe to clean up independently")
	func stagedFileIsDistinctFromSource() throws {
		let source = try makeSourceFile()
		defer { try? FileManager.default.removeItem(at: source) }

		let staged = try StatementFileStaging.stage(source)
		#expect(staged != source)

		StatementFileStaging.cleanup(staged)
		#expect(!FileManager.default.fileExists(atPath: staged.path))
		#expect(FileManager.default.fileExists(atPath: source.path)) // source untouched
	}

	@Test("staging a missing file throws rather than silently producing an empty staged file")
	func stagingMissingFileThrows() {
		let missing = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("pdf")
		#expect(throws: (any Error).self) {
			_ = try StatementFileStaging.stage(missing)
		}
	}

	@Test("cleanup on a nil URL is a no-op")
	func cleanupNilIsNoOp() {
		StatementFileStaging.cleanup(nil)
	}

	@Test("cleanup on an already-removed file does not throw")
	func cleanupAlreadyRemovedDoesNotThrow() throws {
		let source = try makeSourceFile()
		defer { try? FileManager.default.removeItem(at: source) }
		let staged = try StatementFileStaging.stage(source)

		StatementFileStaging.cleanup(staged)
		StatementFileStaging.cleanup(staged) // second call must not throw/crash
	}
}
