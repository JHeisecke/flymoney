//
//  ImportGroupCard.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-08-06.
//

import SwiftUI

/// One group: header (raw detail, row count, total), rename with existing-title
/// suggestions, and its rows. Renaming is this feature's payoff — the caption
/// states plainly what will be remembered.
struct ImportGroupCard: View {
	let group: EditableGroup
	let allTitles: [ExpenseTitle]
	let onRename: @Sendable (String) -> Void
	let onSelectExisting: (ExpenseTitle) -> Void
	let onSetRememberAlias: @Sendable (Bool) -> Void
	let onSetExcluded: (Bool) -> Void
	let onToggleRow: @Sendable (UUID, Bool) -> Void
	let onTapRow: (EditableRow) -> Void
	let onDeleteRow: (UUID) -> Void

	@State private var isEditingName = false
	@FocusState private var isNameFocused: Bool

	private var suggestions: [ExpenseTitle] {
		guard isEditingName, !group.titleName.isEmpty else { return [] }
		let probe = ExpenseTitle(name: group.titleName)
		let matches = MergeMatcher.findMatches(imported: [probe], local: allTitles)[probe.id] ?? []
		return matches.compactMap { match in allTitles.first { $0.id == match.titleID } }
	}

	private var groupTotal: Money {
		let included = group.rows.filter(\.isIncluded)
		guard let currency = included.first?.amount.currencyCode else { return Money.zero("PYG") }
		return included.reduce(Money.zero(currency)) { partial, row in (try? partial.adding(row.amount)) ?? partial }
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			header
			if isEditingName {
				rememberAliasCaption
				if !suggestions.isEmpty { suggestionsList }
			}
			Divider().background(Theme.Colors.borderDivider)
			ForEach(group.rows) { row in
				ImportRowCard(
					row: row,
					onToggleIncluded: { onToggleRow(row.id, $0) },
					onTap: { onTapRow(row) },
					onDelete: { onDeleteRow(row.id) }
				)
				if row.id != group.rows.last?.id {
					Divider().background(Theme.Colors.borderDivider).padding(.leading, Theme.Spacing.xxl)
				}
			}
		}
		.background(Theme.Colors.card)
		.clipShape(.rect(cornerRadius: Theme.Radius.md))
		.opacity(group.isExcluded ? 0.5 : 1)
	}

	private var header: some View {
		HStack(alignment: .top, spacing: Theme.Spacing.md) {
			VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
				Text(group.rawDetail)
					.font(Theme.Typography.caption12)
					.foregroundStyle(Theme.Colors.textSubtle)
				TextField(String(localized: "Category"), text: Binding(get: { group.titleName }, set: onRename))
					.font(Theme.Typography.title16)
					.foregroundStyle(Theme.Colors.ink)
					.textFieldStyle(.plain)
					.focused($isNameFocused)
					.onChange(of: isNameFocused) { _, focused in isEditingName = focused }
			}
            .onTapGesture {
                guard !isEditingName else { return }
                isEditingName = true
            }

			Spacer()

			VStack(alignment: .trailing, spacing: Theme.Spacing.xs) {
				Text(groupTotal.formatted())
					.font(Theme.Typography.title16)
					.foregroundStyle(Theme.Colors.ink)
					.monospacedDigit()
				Button(role: .destructive) {
					onSetExcluded(!group.isExcluded)
				} label: {
					Text(group.isExcluded ? String(localized: "Include group") : String(localized: "Exclude group"))
						.font(Theme.Typography.caption12)
				}
				.buttonStyle(.hapticPlain)
			}
		}
		.padding(Theme.Spacing.lg)
	}

	private var rememberAliasCaption: some View {
		HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
			Text(rememberAliasText)
				.font(Theme.Typography.caption12)
				.foregroundStyle(Theme.Colors.inkTertiary)
			Spacer()
			Toggle(String(localized: "Remember"), isOn: Binding(get: { group.rememberAlias }, set: onSetRememberAlias))
				.labelsHidden()
				.toggleStyle(.switch)
				.tint(Theme.Colors.accent)
				.accessibilityLabel(String(localized: "Remember this name for future imports"))
		}
		.padding(.horizontal, Theme.Spacing.lg)
		.padding(.bottom, Theme.Spacing.sm)
	}

	private var rememberAliasText: String {
		group.rememberAlias
			? String(localized: "\(group.rawDetail) will be saved as \(group.titleName) from now on.")
			: String(localized: "Saved as \(group.titleName) — from a previous import.")
	}

	private var suggestionsList: some View {
		VStack(alignment: .leading, spacing: 0) {
			ForEach(suggestions) { title in
				Button {
					onSelectExisting(title)
					isNameFocused = false
				} label: {
					Text(title.name)
						.font(Theme.Typography.body14)
						.foregroundStyle(Theme.Colors.inkSecondary)
						.frame(maxWidth: .infinity, alignment: .leading)
						.padding(.horizontal, Theme.Spacing.lg)
						.frame(height: 40)
						.contentShape(.rect)
				}
				.buttonStyle(.hapticPlain)
			}
		}
		.padding(.bottom, Theme.Spacing.sm)
	}
}
