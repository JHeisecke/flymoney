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
/// The two cases record **origin**, not presentation — only an inbox file may
/// be deleted after staging (`phaseDidChange`). A manually picked URL points
/// at the user's own document in the Files provider, and must never be removed.
enum ImportRequest: Identifiable, Equatable {
	/// Chosen by the user in the file picker. Not ours to delete.
	case picked(URL)
	/// Written by the share extension into the App Group inbox. Ours to drain.
	case inbox(URL)

	var id: String {
		switch self {
		case .picked(let url): "picked:\(url.absoluteString)"
		case .inbox(let url): "inbox:\(url.absoluteString)"
		}
	}

	var fileURL: URL {
		switch self {
		case .picked(let url), .inbox(let url): url
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

	init(makeViewModel: @escaping () -> ImportStatementViewModel) {
		self.makeViewModel = makeViewModel
	}

	/// The user picked a file. Raised only *after* the picker returns a URL, so
	/// the sheet never appears empty behind it.
	func presentPickedFile(_ url: URL) {
		guard request == nil else { return }
		viewModel = makeViewModel()
		request = .picked(url)
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
	/// Only `.inbox` requests are removed. A `.picked` URL is the user's own
	/// document in the Files provider — deleting it would destroy their file.
	func phaseDidChange(_ phase: ImportStatementViewModel.Phase) {
		guard case .inbox(let url) = request else { return }
		switch phase {
		case .review, .failed: StatementInbox.remove(url)
		default: break
		}
	}
}
