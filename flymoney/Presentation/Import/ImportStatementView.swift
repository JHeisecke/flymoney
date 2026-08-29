//
//  ImportStatementView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-08-06.
//

import SwiftUI
import StatementParsing

/// Editing one row, or adding one. `groupID` is what the view model needs
/// either way; `row` is `nil` when adding.
private struct EditingRowTarget: Identifiable {
	let id: UUID
	let groupID: String
	let row: EditableRow?
}

/// The review screen. Rows are grouped by detected title — that's the unit the
/// user makes decisions about — and each group is folded shut, because the
/// common case is "yes, that merchant is this category" and nothing more.
///
/// A `List`, not a `ScrollView`: the group cards need real swipe actions, and
/// `.swipeActions` outside a `List` silently does nothing.
struct ImportStatementView: View {
	let viewModel: ImportStatementViewModel
	let draft: EditableDraft
	let onCommit: () -> Void
	let onCancel: () -> Void

	@State private var editingRow: EditingRowTarget?
	@State private var showBankPicker = false
	@State private var namingQueries: [String: String] = [:]

	var body: some View {
		NavigationStack {
			ScrollViewReader { proxy in
				List {
					summarySection
					if viewModel.attentionCount > 0 {
						attentionBanner { scrollToFirstAttention(proxy) }
					}
					groupRows(proxy)
				}
				.listStyle(.plain)
				.listRowSpacing(Theme.Spacing.xs)
				.scrollContentBackground(.hidden)
				.scrollDismissesKeyboard(.automatic)
				.background(Theme.Colors.surface)
			}
			.navigationTitle(Text(String(localized: "Review import")))
			.navigationBarTitleDisplayMode(.inline)
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
				ToolbarItem(placement: .topBarTrailing) {
					Menu {
						Button(String(localized: "Change bank"), systemImage: "building.columns") {
							showBankPicker = true
						}
					} label: {
						Image(systemName: "ellipsis")
							.foregroundStyle(Theme.Colors.textSubtle)
					}
					.accessibilityLabel(String(localized: "More options"))
				}
			}
			.safeAreaInset(edge: .bottom) { commitBar }
			.tint(Theme.Colors.accent)
		}
		.sheet(item: $editingRow) { target in
			rowEditor(for: target)
				.presentationDragIndicator(.visible)
		}
		.sheet(isPresented: $showBankPicker) {
			BankProfilePickerHost(viewModel: viewModel, onDismiss: { showBankPicker = false })
		}
	}

	// MARK: - Summary

	/// One block instead of the old header + issues + totals card: what this is,
	/// what it adds up to, and — only when a statement genuinely spans months —
	/// how that total splits.
	private var summarySection: some View {
		VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
			Text(sourceLabel)
				.font(Theme.Typography.caption12)
				.foregroundStyle(Theme.Colors.textSubtle)
				.lineLimit(1)
			Text(grandTotal.formatted())
				.font(Theme.Typography.display32)
				.foregroundStyle(Theme.Colors.ink)
				.monospacedDigit()
				.lineLimit(1)
				.minimumScaleFactor(0.6)
			Text(countAndMonthsCaption)
				.font(Theme.Typography.body13)
				.foregroundStyle(Theme.Colors.inkTertiary)
			if monthTotals.count > 1 {
				ForEach(monthTotals, id: \.key) { month, total in
					HStack {
						Text(monthLabel(month))
							.font(Theme.Typography.caption12)
							.foregroundStyle(Theme.Colors.inkTertiary)
						Spacer()
						Text(total.formatted())
							.font(Theme.Typography.caption12)
							.foregroundStyle(Theme.Colors.inkSecondary)
							.monospacedDigit()
					}
				}
				.padding(.top, Theme.Spacing.xs)
			}
			if !draft.source.issues.isEmpty { issuesLine }
		}
		.padding(.top, Theme.Spacing.sm)
		.listRowInsets(EdgeInsets(top: 0, leading: Theme.Spacing.xxl, bottom: Theme.Spacing.sm, trailing: Theme.Spacing.xxl))
		.listRowBackground(Color.clear)
		.listRowSeparator(.hidden)
		.accessibilityElement(children: .combine)
	}

	private var monthTotals: [(key: CalendarMonth, value: Money)] {
		draft.totalsByMonth(using: .current)
			.sorted { $0.key.key < $1.key.key }
			.map { (key: $0.key, value: $0.value) }
	}

	private var grandTotal: Money {
		let rows = draft.includedRows
		guard let currency = rows.first?.amount.currencyCode else { return Money.zero(draft.source.currencyCode) }
		return rows.reduce(Money.zero(currency)) { partial, row in (try? partial.adding(row.amount)) ?? partial }
	}

	/// Every bundled profile's display name already states both the bank and the
	/// document kind ("Banco GNB — Extracto de tarjeta", "— Estado de cuenta"),
	/// so appending the kind label said the same thing twice and wrapped to two
	/// lines. The kind is appended only for a profile whose name doesn't say it.
	private var sourceLabel: String {
		let name = draft.source.profileDisplayName
		let kind = switch draft.source.kind {
		case .creditCard: String(localized: "Card statement")
		case .bankAccount: String(localized: "Bank account statement")
		}
		return name.contains("—") ? name : "\(name) · \(kind)"
	}

	private var countAndMonthsCaption: String {
		let count = draft.includedRows.count
		guard let first = monthTotals.first?.key else { return String(localized: "\(count) expenses") }
		guard monthTotals.count > 1, let last = monthTotals.last?.key else {
			return "\(String(localized: "\(count) expenses")) · \(monthLabel(first))"
		}
		return "\(String(localized: "\(count) expenses")) · \(monthLabel(first)) – \(monthLabel(last))"
	}

	private var issuesLine: some View {
		let pages = Set(draft.source.issues.map(\.pageIndex)).sorted().map { $0 + 1 }
		let pagesText = pages.map(String.init).joined(separator: ", ")
		return Text(String(localized: "\(draft.source.issues.count) rows couldn\u{2019}t be read (page \(pagesText))"))
			.font(Theme.Typography.caption12)
			.foregroundStyle(Theme.Colors.warning)
			.padding(.top, Theme.Spacing.xs)
	}

	// MARK: - Attention

	/// The only place the screen raises its voice. Everything else the parser
	/// was sure about stays folded and silent.
	private func attentionBanner(_ onTap: @escaping () -> Void) -> some View {
		Button(action: onTap) {
			HStack(spacing: Theme.Spacing.sm) {
				Image(systemName: "exclamationmark.triangle.fill")
					.font(Theme.Typography.caption13Strong)
				Text(String(localized: "\(viewModel.attentionCount) rows to review"))
					.font(Theme.Typography.caption13Strong)
				Spacer()
				Image(systemName: "chevron.right")
					.font(Theme.Typography.caption12)
			}
			.foregroundStyle(Theme.Colors.warning)
			.padding(.horizontal, Theme.Spacing.s14)
			.padding(.vertical, Theme.Spacing.md)
			.background(Theme.Colors.warningTint)
			.clipShape(.rect(cornerRadius: Theme.Radius.md))
			.contentShape(.rect)
		}
		.buttonStyle(.hapticPlain)
		.listRowInsets(EdgeInsets(top: 0, leading: Theme.Spacing.xxl, bottom: Theme.Spacing.sm, trailing: Theme.Spacing.xxl))
		.listRowBackground(Color.clear)
		.listRowSeparator(.hidden)
	}

	private func scrollToFirstAttention(_ proxy: ScrollViewProxy) {
		guard let target = draft.groups.first(where: { viewModel.groupNeedsAttention($0) }) else { return }
		withAnimation { proxy.scrollTo(target.id, anchor: .top) }
	}

	// MARK: - Groups

	private func groupRows(_ proxy: ScrollViewProxy) -> some View {
		ForEach(draft.groups) { group in
			ImportGroupCard(
				group: group,
				needsAttention: viewModel.groupNeedsAttention(group),
				suggestions: viewModel.suggestions(for: namingQueries[group.id] ?? group.titleName),
				limitsByTitleID: viewModel.limitsByTitleID,
				isNewName: viewModel.isNewTitleName(group.titleName),
				// `ImportGroupCard` takes these as `@Sendable` because SwiftUI's
				// `Binding` setters are — but SwiftUI only ever calls them on the
				// main actor, which is what `assumeIsolated` states here rather
				// than hopping and losing the edit's ordering.
				onRename: { newName in
					MainActor.assumeIsolated {
						namingQueries[group.id] = newName
						viewModel.rename(groupID: group.id, to: newName)
					}
				},
				onSelectExisting: {
					namingQueries[group.id] = $0.name
					viewModel.selectExistingTitle(groupID: group.id, title: $0)
				},
				onSetRememberAlias: { value in
					MainActor.assumeIsolated { viewModel.setRememberAlias(groupID: group.id, value) }
				},
				onSetExcluded: { viewModel.setGroupExcluded(groupID: group.id, $0) },
				onToggleRow: { rowID, included in
					MainActor.assumeIsolated { viewModel.setRowIncluded(groupID: group.id, rowID: rowID, included) }
				},
				onTapRow: { row in editingRow = EditingRowTarget(id: row.id, groupID: group.id, row: row) },
				onDeleteRow: { rowID in viewModel.deleteRow(groupID: group.id, rowID: rowID) },
				onAddRow: { editingRow = EditingRowTarget(id: UUID(), groupID: group.id, row: nil) },
				onBeginNaming: {
					withAnimation { proxy.scrollTo(group.id, anchor: .top) }
				}
			)
			.id(group.id)
			.listRowInsets(EdgeInsets(top: 0, leading: Theme.Spacing.xxl, bottom: 0, trailing: Theme.Spacing.xxl))
			.listRowBackground(Color.clear)
			.listRowSeparator(.hidden)
		}
	}

	// MARK: - Row editor

	@ViewBuilder private func rowEditor(for target: EditingRowTarget) -> some View {
		let groupName = draft.groups.first { $0.id == target.groupID }?.titleName ?? ""
		if let row = target.row {
			ImportRowEditor(
				groupTitleName: groupName,
				flagNotes: ImportRowFlagCopy.sentences(for: row.flags, groupTitleName: groupName),
				date: row.date, amount: row.amount, rawDetail: row.rawDetail,
				onSave: { date, amount, rawDetail in
					viewModel.updateRow(groupID: target.groupID, rowID: row.id, date: date, amount: amount, rawDetail: rawDetail)
					editingRow = nil
				},
				onDelete: {
					viewModel.deleteRow(groupID: target.groupID, rowID: row.id)
					editingRow = nil
				},
				onCancel: { editingRow = nil }
			)
		} else {
			ImportRowEditor(
				groupTitleName: groupName,
				flagNotes: [],
				date: .now,
				amount: Money.zero(draft.source.currencyCode),
				rawDetail: draft.groups.first { $0.id == target.groupID }?.rawDetail ?? "",
				onSave: { date, amount, rawDetail in
					viewModel.addRow(groupID: target.groupID, date: date, amount: amount, rawDetail: rawDetail)
					editingRow = nil
				},
				onDelete: nil,
				onCancel: { editingRow = nil }
			)
		}
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
