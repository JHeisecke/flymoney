//
//  TitlesView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

struct TitlesView: View {
	@State private var viewModel: TitlesViewModel
	@State private var showAllTitles = false
	@State private var showTemplate = false
	@State private var sharingRole: SharingRole?
	@Environment(\.haptics) private var haptics
	let assembly: AppAssembly
	let onExpenseDeleted: @MainActor () async -> Void

	init(viewModel: TitlesViewModel, assembly: AppAssembly, onExpenseDeleted: @escaping @MainActor () async -> Void) {
		self.viewModel = viewModel
		self.assembly = assembly
		self.onExpenseDeleted = onExpenseDeleted
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			header
			MonthHeaderView(
				month: viewModel.month,
				calendar: viewModel.calendar,
				onPrevious: { viewModel.previousMonth() },
				onNext: { viewModel.nextMonth() }
			)
			.padding(.horizontal, Theme.Spacing.xxl)
			.padding(.bottom, Theme.Spacing.md)
			content
		}
		.background(Theme.Colors.surface)
		.sheet(isPresented: $showTemplate, onDismiss: { Task { await viewModel.load() } }) {
			BudgetTemplateView(
				model: assembly.makeBudgetTemplateViewModel(), onApplied: { viewModel.month = $0 })
		}
		.sheet(item: $sharingRole, onDismiss: { Task { await viewModel.load() } }) { role in
			SharingSheetHost(assembly: assembly, role: role, includeExpensesInitially: false)
		}
		.task { await viewModel.load() }
		.onChange(of: viewModel.month) { _, _ in
			Task { await viewModel.load() }
		}
		.onChange(of: viewModel.loadError) { _, error in
			if error != nil { haptics.error() }
		}
		.onChange(of: viewModel.deleteBlocked) { _, blocked in
			if blocked != nil { haptics.error() }
		}
		.sheet(item: $viewModel.editor) { editorVM in
			TitleEditorView(
				viewModel: editorVM,
				onSave: { await viewModel.save(editorVM.form) },
				onCancel: { viewModel.editor = nil },
				onExpenseDeleted: onExpenseDeleted
			)
			.presentationDragIndicator(.visible)
		}
		.alert(
			Text(Lexicon.Term.singular.text),
			isPresented: isDeleteBlockedPresented,
			presenting: viewModel.deleteBlocked
		) { _ in
			Button(String(localized: "OK"), role: .cancel) {

			}
		} message: {
			Text($0)
		}
		.sheet(
			isPresented: $showAllTitles,
			onDismiss: {
				Task { await viewModel.load() }
			}
		) {
			AllTitlesManagementView(
				viewModel: assembly.makeAllTitlesManagementViewModel(month: viewModel.month),
				onExpenseDeleted: onExpenseDeleted)
		}
	}

	private var header: some View {
		HStack {
			Button {
				showAllTitles = true
			} label: {
				Text(Lexicon.Term.plural.text)
					.font(Theme.Typography.display27)
					.tracking(-0.5)
					.foregroundStyle(Theme.Colors.ink)
			}
			.buttonStyle(.hapticPlain)
			Spacer()
			Menu {
				Button("Load template", systemImage: "list.bullet.rectangle") { showTemplate = true }
				Button("Share limits", systemImage: "qrcode") {
					sharingRole = .send(month: viewModel.month)
				}
				Button("Receive budget", systemImage: "qrcode.viewfinder") { sharingRole = .receive }
			} label: {
				Label("Budget actions", systemImage: "ellipsis.circle")
			}
			.labelStyle(.iconOnly)
			PillButton(title: "New", systemImage: "plus") {
				viewModel.beginCreate()
			}
		}
		.padding(.horizontal, Theme.Spacing.xxl)
		.padding(.vertical, Theme.Spacing.s18)
	}

	@ViewBuilder private var content: some View {
		if viewModel.isLoading {
			EmptyView()
		} else if viewModel.titles.isEmpty {
			empty
		} else if viewModel.visibleTitles.isEmpty {
			monthEmpty
		} else {
			ScrollView {
				VStack(spacing: Theme.Spacing.md) {
					ForEach(viewModel.visibleTitles) { title in
						if let limit = viewModel.limitByTitle[title.id] {
							TitleCardView(
								title: title,
								spent: viewModel.spentByTitle[title.id]
									?? Money.zero(limit.currencyCode),
								limit: limit
							) { viewModel.beginEdit(title) }
							.contextMenu {
								Button {
									viewModel.beginEdit(title)
								} label: {
									Label(
										String(localized: Lexicon.editTerm),
										systemImage: "pencil")
								}
								Button(role: .destructive) {
									haptics.warning()
									Task { await viewModel.delete(title) }
								} label: {
									Label(
										String(localized: Lexicon.deleteTerm),
										systemImage: "trash")
								}
							}
						} else {
							let noLimitCurrency =
								viewModel.spentByTitle[title.id]?.currencyCode
								?? viewModel.currencyCode
							TitleNoLimitRowView(
								title: title,
								spent: viewModel.spentByTitle[title.id]
									?? Money.zero(noLimitCurrency)
							) { viewModel.beginEdit(title) }
							.contextMenu {
								Button {
									viewModel.beginEdit(title)
								} label: {
									Label(
										String(localized: Lexicon.editTerm),
										systemImage: "pencil")
								}
								Button(role: .destructive) {
									haptics.warning()
									Task { await viewModel.delete(title) }
								} label: {
									Label(
										String(localized: Lexicon.deleteTerm),
										systemImage: "trash")
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
	}

	private var monthEmpty: some View {
		ContentUnavailableView {
			Label {
				Text(Lexicon.noneThisMonth)
					.font(Theme.Typography.title17)
			} icon: {
				Image(systemName: "tag")
					.foregroundStyle(Theme.Colors.accent)
			}
		}
	}

	private var isDeleteBlockedPresented: Binding<Bool> {
		Binding(
			get: { viewModel.deleteBlocked != nil },
			set: { if !$0 { viewModel.deleteBlocked = nil } })
	}
}
