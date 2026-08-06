//
//  StatementFileStaging.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-08-06.
//

import Foundation

/// `.fileImporter` hands back a URL outside the app sandbox. `PDFDocument(url:)`
/// returns `nil` without an open security scope, which the parser surfaces as
/// `unreadableDocument` — indistinguishable from a genuinely corrupt PDF.
/// Copying the picked file into the app's own temporary directory first makes
/// the rest of the flow a plain local-file read, and keeps the scope's
/// lifetime explicit instead of held open across an `async` parse.
enum StatementFileStaging {
	/// `startAccessingSecurityScopedResource()`'s return value is advisory,
	/// not authoritative: Apple returns `false` both when access is genuinely
	/// denied and when the URL was never security-scoped to begin with (e.g.
	/// a plain local file, as in tests) — that case is harmless. The copy's
	/// own success is the real signal.
	static func stage(_ picked: URL, fileManager: FileManager = .default) throws -> URL {
		let scoped = picked.startAccessingSecurityScopedResource()
		defer { if scoped { picked.stopAccessingSecurityScopedResource() } }

		let staged = fileManager.temporaryDirectory
			.appendingPathComponent(UUID().uuidString)
			.appendingPathExtension("pdf")
		do {
			try fileManager.copyItem(at: picked, to: staged)
		} catch {
			throw scoped ? ImportFileError.stagingFailed : ImportFileError.accessDenied
		}
		return staged
	}

	/// Deletes the staged copy. Called on commit, cancel **and** error — never
	/// left for the OS to reclaim.
	static func cleanup(_ staged: URL?, fileManager: FileManager = .default) {
		guard let staged else { return }
		try? fileManager.removeItem(at: staged)
	}
}
