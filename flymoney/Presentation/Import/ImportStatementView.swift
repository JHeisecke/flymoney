//
//  ImportStatementView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-08-06.
//

import SwiftUI
import StatementParsing

private struct EditingRowTarget: Identifiable {
	let id: UUID
	let groupID: String
	let row: EditableRow
}

/// The review screen. Rows are grouped by detected title — that's the unit
/// the user makes decisions about.
struct ImportStatementView: View {
	let viewModel: ImportStatementViewModel
	let draft: EditableDraft
	let onCommit: () -> Void
	let onCancel: () -> Void

	@State private var editingRow: EditingRowTarget?
	@State private var showBankPicker = false

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
					kindAndBankHeader
					if !draft.source.issues.isEmpty { issuesLine }
					totalsSection
					ForEach(draft.groups) { group in
						ImportGroupCard(
							group: group,
							allTitles: viewModel.allTitles,
							onRename: { viewModel.rename(groupID: group.id, to: $0) },
							onSelectExisting: { viewModel.selectExistingTitle(groupID: group.id, title: $0) },
							onSetRememberAlias: { viewModel.setRememberAlias(groupID: group.id, $0) },
							onSetExcluded: { viewModel.setGroupExcluded(groupID: group.id, $0) },
							onToggleRow: { rowID, included in viewModel.setRowIncluded(groupID: group.id, rowID: rowID, included) },
							onTapRow: { row in editingRow = EditingRowTarget(id: row.id, groupID: group.id, row: row) },
							onDeleteRow: { rowID in viewModel.deleteRow(groupID: group.id, rowID: rowID) }
						)
					}
				}
				.padding(.horizontal, Theme.Spacing.xxl)
				.padding(.top, Theme.Spacing.lg)
				.padding(.bottom, Theme.Spacing.s42)
			}
            .scrollDismissesKeyboard(.automatic)
			.background(Theme.Colors.surface)
			.navigationTitle(Text(String(localized: "Review import")))
			.toolbar {
				ToolbarItem(placement: .topBarLeading) {
					Button {
						onCancel()
					} label: {
						Image(systemName: "xmark")
							.foregroundStyle(Theme.Colors.textSubtle)
					}
					.buttonStyle(.hapticPlain)
					.accessibilityLabel(String(localized: "Cancel"))
				}
			}
			.safeAreaInset(edge: .bottom) {
				commitBar
			}
			.tint(Theme.Colors.accent)
		}
		.sheet(item: $editingRow) { target in
			ImportRowEditor(
				groupTitleName: draft.groups.first { $0.id == target.groupID }?.titleName ?? target.row.rawDetail,
				date: target.row.date, amount: target.row.amount, rawDetail: target.row.rawDetail,
				onSave: { date, amount, rawDetail in
					viewModel.updateRow(groupID: target.groupID, rowID: target.row.id, date: date, amount: amount, rawDetail: rawDetail)
					editingRow = nil
				},
				onCancel: { editingRow = nil }
			)
			.presentationDragIndicator(.visible)
		}
		.sheet(isPresented: $showBankPicker) {
			BankProfilePickerHost(viewModel: viewModel, onDismiss: { showBankPicker = false })
		}
	}

	private var kindAndBankHeader: some View {
		HStack {
			VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
				Text(kindLabel)
					.font(Theme.Typography.caption12)
					.foregroundStyle(Theme.Colors.textSubtle)
				Text(draft.source.profileDisplayName)
					.font(Theme.Typography.title16)
					.foregroundStyle(Theme.Colors.ink)
			}
			Spacer()
			Button(String(localized: "Change bank")) {
				showBankPicker = true
			}
			.font(Theme.Typography.caption13Strong)
			.foregroundStyle(Theme.Colors.accent)
			.buttonStyle(.hapticPlain)
		}
	}

	private var kindLabel: String {
		switch draft.source.kind {
		case .creditCard: String(localized: "Card statement")
		case .bankAccount: String(localized: "Bank account statement")
		}
	}

	private var issuesLine: some View {
		let pages = Set(draft.source.issues.map(\.pageIndex)).sorted().map { $0 + 1 }
		let pagesText = pages.map(String.init).joined(separator: ", ")
		return Text(String(localized: "\(draft.source.issues.count) rows couldn\u{2019}t be read (page \(pagesText))"))
			.font(Theme.Typography.caption12)
			.foregroundStyle(Theme.Colors.warning)
	}

	private var totalsSection: some View {
		let totals = draft.totalsByMonth(using: .current).sorted { $0.key.key < $1.key.key }
		return VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
			ForEach(totals, id: \.key) { month, total in
				HStack {
					Text(monthLabel(month))
						.font(Theme.Typography.body14)
						.foregroundStyle(Theme.Colors.inkSecondary)
					Spacer()
					Text(total.formatted())
						.font(Theme.Typography.body16)
						.foregroundStyle(Theme.Colors.ink)
						.monospacedDigit()
				}
			}
		}
		.padding(Theme.Spacing.lg)
		.background(Theme.Colors.card)
		.clipShape(.rect(cornerRadius: Theme.Radius.md))
	}

	private func monthLabel(_ month: CalendarMonth) -> String {
		month.interval(using: .current).start.formatted(.dateTime.month(.wide).year().locale(.current))
	}

	private var commitBar: some View {
		SaveButton(
			title: "Add \(draft.includedRows.count) expenses",
			isLoading: false,
			isDisabled: draft.includedRows.isEmpty
		) {
			onCommit()
		}
		.padding(.horizontal, Theme.Spacing.xxl)
		.padding(.top, Theme.Spacing.md)
		.padding(.bottom, Theme.Spacing.lg)
		.background(Theme.Colors.surface)
	}
}

/// Loads `viewModel.availableProfiles()` before presenting the picker.
private struct BankProfilePickerHost: View {
	let viewModel: ImportStatementViewModel
	let onDismiss: () -> Void

	@State private var profiles: [StatementProfile] = []

	var body: some View {
		BankProfilePicker(
			profiles: profiles,
			onSelect: { profile in
				Task {
					await viewModel.overrideProfile(profile.id)
					onDismiss()
				}
			},
			onCancel: onDismiss
		)
		.task {
			profiles = await viewModel.availableProfiles()
		}
	}
}
