//
//  AllTitlesManagementView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-07-01.
//

import SwiftUI

struct AllTitlesManagementView: View {
	@State private var viewModel: AllTitlesManagementViewModel

	init(viewModel: AllTitlesManagementViewModel) {
		_viewModel = State(initialValue: viewModel)
	}

	var body: some View {
		VStack {
			Text(Lexicon.Term.plural.text)
				.font(Theme.Typography.display27)
				.tracking(-0.5)
				.foregroundStyle(Theme.Colors.ink)
                .padding(.vertical)
			if viewModel.titles.isEmpty && !viewModel.isLoading {
				ContentUnavailableView {
					Label {
						Text(Lexicon.noneYet)
							.font(Theme.Typography.title17)
					} icon: {
						Image(systemName: "tag")
							.foregroundStyle(Theme.Colors.accent)
					}
				} description: {
					Text(Lexicon.emptyStatePrompt)
						.font(Theme.Typography.body14)
						.foregroundStyle(Theme.Colors.inkQuaternary)
				}
			} else {
				List {
					ForEach(viewModel.titles) { title in
						Text(title.name)
							.font(Theme.Typography.body16)
					}
					.onDelete { indexSet in
						let targets = indexSet.map { viewModel.titles[$0] }
						Task { for title in targets { await viewModel.requestDelete(title) } }
					}
				}
				.listStyle(.plain)
			}
		}
		.task { await viewModel.load() }
		.alert(
			Text(String(format: String(localized: "Delete \"%@\"?"), viewModel.pendingDelete?.title.name ?? "")),
			isPresented: pendingDeletePresented,
			presenting: viewModel.pendingDelete
		) { pending in
			Button(String(localized: "OK"), role: .destructive) {
				Task { await viewModel.confirmPendingDelete() }
			}
			Button(String(localized: "Cancel"), role: .cancel) {
				viewModel.cancelPendingDelete()
			}
		} message: { pending in
			Text(String(format: String(localized: "This category has %lld expenses. Deleting it would delete all expenses saved under this title."), pending.expenseCount))
		}
		.alert(
			Text(String(localized: "Couldn\u{2019}t delete. Try again.")),
			isPresented: loadErrorPresented
		) {
			Button(String(localized: "OK"), role: .cancel) { viewModel.loadError = nil }
		}
	}

	private var pendingDeletePresented: Binding<Bool> {
		Binding(get: { viewModel.pendingDelete != nil },
				set: { if !$0 { viewModel.cancelPendingDelete() } })
	}

	private var loadErrorPresented: Binding<Bool> {
		Binding(get: { viewModel.loadError != nil },
				set: { if !$0 { viewModel.loadError = nil } })
	}
}
