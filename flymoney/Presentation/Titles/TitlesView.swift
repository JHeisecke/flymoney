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
		VStack(alignment: .leading, spacing: 0) {
			header
			content
		}
		.background(Theme.Colors.surface)
		.task { await viewModel.load() }
		.sheet(item: $viewModel.editor) { model in
			TitleEditorView(
				model: model,
				onSave: { await viewModel.save(model) },
				onCancel: { viewModel.editor = nil })
		}
		.alert(Text(Lexicon.titleSingular),
			   isPresented: isDeleteBlockedPresented,
			   presenting: viewModel.deleteBlocked) { _ in
			Button(String(localized: "OK"), role: .cancel) {}
		} message: { Text($0) }
	}

	private var header: some View {
		HStack {
			Text(Lexicon.titlesPlural)
				.font(Theme.Typography.display27)
				.tracking(-0.5)
				.foregroundStyle(Theme.Colors.ink)
			Spacer()
			PillButton(title: "New", systemImage: "plus") {
				viewModel.beginCreate()
			}
		}
		.padding(.horizontal, Theme.Spacing.xxl)
		.padding(.vertical, Theme.Spacing.s18)
	}

	@ViewBuilder private var content: some View {
		if viewModel.titles.isEmpty && !viewModel.isLoading {
			empty
		} else {
			ScrollView {
				VStack(spacing: Theme.Spacing.md) {
					ForEach(viewModel.titles) { title in
						let currency = title.limit?.currencyCode ?? "USD"
						if let limit = title.limit {
							TitleCardView(
								title: title,
								spent: viewModel.spentByTitle[title.id] ?? Money.zero(currency),
								limit: limit
							) { viewModel.beginEdit(title) }
								.contextMenu {
									Button {
										viewModel.beginEdit(title)
									} label: {
										Label(String(localized: "Edit title"), systemImage: "pencil")
									}
									Button(role: .destructive) {
										Task { await viewModel.delete(title) }
									} label: {
										Label(String(localized: "Delete title"), systemImage: "trash")
									}
								}
					} else {
						let noLimitCurrency = viewModel.spentByTitle[title.id]?.currencyCode ?? viewModel.currencyCode
						TitleNoLimitRowView(
							title: title,
							spent: viewModel.spentByTitle[title.id] ?? Money.zero(noLimitCurrency)
						) { viewModel.beginEdit(title) }
								.contextMenu {
									Button {
										viewModel.beginEdit(title)
									} label: {
										Label(String(localized: "Edit title"), systemImage: "pencil")
									}
									Button(role: .destructive) {
										Task { await viewModel.delete(title) }
									} label: {
										Label(String(localized: "Delete title"), systemImage: "trash")
									}
								}
						}
					}
				}
				.padding(.horizontal, Theme.Spacing.s18)
				.padding(.bottom, Theme.Spacing.xxxl)
			}
		}
	}

	private var empty: some View {
		ContentUnavailableView {
			Label {
				Text(Lexicon.noTitlesYet)
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
	}

	private var isDeleteBlockedPresented: Binding<Bool> {
		Binding(get: { viewModel.deleteBlocked != nil },
				set: { if !$0 { viewModel.deleteBlocked = nil } })
	}
}
