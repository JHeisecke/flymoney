//
//  StatementImportDrainCoordinator.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-08-06.
//

import Foundation

/// The single import-sheet presentation site. Always carries a URL: the sheet
/// is only raised once a file exists, so it never renders empty. The file
/// picker lives outside the sheet (`RootView`), because presenting a sheet
/// whose only job is to raise a *second* sheet shows the user a blank one
/// behind the picker.
///
/// The cases record **origin**, not presentation — origin is what decides
/// whether the file may be deleted after staging (`phaseDidChange`). Deleting
/// a document the user still owns would be data loss, so the rule is per case
/// and never inferred from the URL alone.
enum ImportRequest: Identifiable, Equatable {
	/// Chosen by the user in the file picker. Points at their own document in
	/// the Files provider. Not ours to delete.
	case picked(URL)
	/// Written by the share extension into the App Group inbox. Ours to drain.
	case inbox(URL)
	/// Handed over by `onOpenURL` — "Open in flymoney" from the share sheet,
	/// or a PDF opened from another app. Deletable **only** when iOS copied
	/// the file into our own `Documents/Inbox/`, which it does for a source
	/// that does not open documents in place; that copy is ours and nothing
	/// else ever removes it. When the document opens in place the URL is the
	/// user's own file, security-scoped, and must survive the import.
	case opened(URL)

	var id: String {
		switch self {
		case .picked(let url): "picked:\(url.absoluteString)"
		case .inbox(let url): "inbox:\(url.absoluteString)"
		case .opened(let url): "opened:\(url.absoluteString)"
		}
	}

	var fileURL: URL {
		switch self {
		case .picked(let url), .inbox(let url), .opened(let url): url
		}
	}
}

/// Owns the share-extension inbox drain and the single import-sheet request,
/// separated from `RootView` so the seam between `StatementInbox` and
/// `ImportStatementViewModel` — when an inbox entry gets removed — is
/// testable without SwiftUI.
@MainActor
@Observable
final class StatementImportDrainCoordinator {
	var request: ImportRequest?
	private(set) var viewModel: ImportStatementViewModel?

	private let makeViewModel: () -> ImportStatementViewModel
	private let fileManager: FileManager

	init(makeViewModel: @escaping () -> ImportStatementViewModel, fileManager: FileManager = .default) {
		self.makeViewModel = makeViewModel
		self.fileManager = fileManager
	}

	/// The user picked a file. Raised only *after* the picker returns a URL, so
	/// the sheet never appears empty behind it.
	func presentPickedFile(_ url: URL) {
		guard request == nil else { return }
		viewModel = makeViewModel()
		request = .picked(url)
	}

	/// A document handed over by the system — "Open in flymoney" from the share
	/// sheet, or any app opening a PDF with flymoney. Unlike the extension's
	/// inbox drop, this one brings the app to the front, so the review screen
	/// appears without the user foregrounding anything themselves.
	///
	/// An import already on screen wins: replacing it mid-review would throw
	/// away edits the user has made. The dropped file is announced by the
	/// system only once, so it is not queued — the user re-opens it.
	func presentOpenedFile(_ url: URL) {
		guard request == nil else { return }
		viewModel = makeViewModel()
		request = .opened(url)
	}

	/// One file at a time, oldest first — the review screen is a
	/// single-document flow and two sheets must never stack. Call on cold
	/// launch and on foreground return: idempotent either way, since
	/// `StatementInbox.pending()` returns nothing once drained.
	func drain() async {
		guard request == nil, viewModel == nil else { return }
		StatementInbox.evictStale()
		guard let next = StatementInbox.pending().first else { return }
		viewModel = makeViewModel()
		request = .inbox(next)
	}

	/// Call when the sheet's request clears — manual dismiss, cancel, or
	/// SwiftUI's own swipe-to-dismiss via the `$request` binding.
	func requestDidClear() {
		viewModel = nil
	}

	/// Removed after staging resolves — success (`.review`) or failure
	/// (`.failed`) — never after commit: waiting for commit would re-present
	/// the same file after every cancel, with no way to dismiss it.
	///
	/// `.inbox` requests are always removed. An `.opened` request is removed
	/// only when iOS copied the document into our own `Documents/Inbox/`
	/// (`isSystemDropbox`) — that copy exists for this import and nothing else
	/// reclaims it. A `.picked` URL, and an `.opened` one that resolved in
	/// place, are the user's own document — deleting either would destroy
	/// their file.
	func phaseDidChange(_ phase: ImportStatementViewModel.Phase) {
		switch phase {
		case .review, .failed: removeIfOurs()
		default: break
		}
	}

	private func removeIfOurs() {
		switch request {
		case .inbox(let url):
			StatementInbox.remove(url)
		case .opened(let url) where isSystemDropbox(url):
			StatementInbox.remove(url)
		default:
			break
		}
	}

	/// A document opened from a source that does not support opening in place
	/// arrives as a copy iOS made inside the app's own `Documents/Inbox/`.
	/// Everything else — a Files document opened in place, a picked file —
	/// lives outside the sandbox and belongs to the user.
	private func isSystemDropbox(_ url: URL) -> Bool {
		guard let documents = try? fileManager.url(
			for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false
		) else { return false }
		let dropbox = documents.appending(path: "Inbox", directoryHint: .isDirectory)
		return url.resolvingSymlinksInPath().path(percentEncoded: false)
			.hasPrefix(dropbox.resolvingSymlinksInPath().path(percentEncoded: false))
	}
}
