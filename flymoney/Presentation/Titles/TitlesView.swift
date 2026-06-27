//
//  TitlesView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

struct TitlesView: View {
	@State private var viewModel: TitlesViewModel

	init(viewModel: TitlesViewModel) {
		_viewModel = State(initialValue: viewModel)
	}

	var body: some View {
		NavigationStack {
			Group {
				if viewModel.titles.isEmpty && !viewModel.isLoading {
					ContentUnavailableView {
						Label {
							Text(Lexicon.noTitlesYet)
						} icon: {
							Image(systemName: "tag")
								.foregroundStyle(Theme.Colors.accent)
						}
					} description: {
						Text(Lexicon.emptyStatePrompt)
					}
				} else {
					List {
						ForEach(viewModel.titles) { title in
							Button {
								viewModel.beginEdit(title)
							} label: {
								TitleRowView(title: title)
							}
						}
						.onDelete { offsets in
							for offset in offsets {
								let title = viewModel.titles[offset]
								Task { await viewModel.delete(title) }
							}
						}
					}
				}
			}
			.navigationTitle(Text(Lexicon.titlesPlural))
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					Button(String(localized: "Add"), systemImage: "plus") {
						viewModel.beginCreate()
					}
				}
			}
			.task { await viewModel.load() }
			.sheet(item: $viewModel.editor) { model in
				TitleEditorView(
					model: model,
					onSave: { await viewModel.save(model) },
					onCancel: { viewModel.editor = nil }
				)
			}
			.alert(Text(Lexicon.titleSingular), isPresented: isDeleteBlockedPresented,
				   presenting: viewModel.deleteBlocked) { _ in
				Button(String(localized: "OK"), role: .cancel) {}
			} message: { Text($0) }
		}
		.tint(Theme.Colors.accent)
	}

	private var isDeleteBlockedPresented: Binding<Bool> {
		Binding(
			get: { viewModel.deleteBlocked != nil },
			set: { if !$0 { viewModel.deleteBlocked = nil } }
		)
	}
}
