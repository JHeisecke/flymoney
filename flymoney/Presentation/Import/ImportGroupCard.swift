//
//  ImportGroupCard.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-08-06.
//

import SwiftUI

/// One merchant, folded shut. The header carries the decision the user actually
/// makes — what category this merchant is — and the rows sit behind a tap,
/// because in the common case they need nothing but a glance at the total.
///
/// A group holding a row the parser could not settle (`needsAttention`) opens
/// by itself: the screen should arrive with exactly the questionable parts
/// unfolded.
struct ImportGroupCard: View {
	let group: EditableGroup
	let needsAttention: Bool
	let suggestions: [ExpenseTitle]
	let limitsByTitleID: [UUID: Money]
	let isNewName: Bool
	let onRename: @Sendable (String) -> Void
	let onSelectExisting: (ExpenseTitle) -> Void
	let onSetRememberAlias: @Sendable (Bool) -> Void
	let onSetExcluded: (Bool) -> Void
	let onToggleRow: @Sendable (UUID, Bool) -> Void
	let onTapRow: (EditableRow) -> Void
	let onDeleteRow: (UUID) -> Void
	let onAddRow: () -> Void
	/// Lets the screen scroll this card to the top: the dropdown opens below the
	/// field, and a group sitting low in the list would open it behind the
	/// commit bar and the keyboard.
	let onBeginNaming: () -> Void

	@State private var isExpanded: Bool?
	@State private var isNaming = false
	@FocusState private var isNameFocused: Bool

	/// Nil until the user touches it, so a group that starts open because it
	/// needs attention still closes on tap — and one they opened by hand does
	/// not slam shut when the draft mutates.
	private var expanded: Bool { isExpanded ?? needsAttention }

	private var includedRows: [EditableRow] { group.rows.filter(\.isIncluded) }

	private var groupTotal: Money {
		guard let currency = includedRows.first?.amount.currencyCode else { return Money.zero("PYG") }
		return includedRows.reduce(Money.zero(currency)) { partial, row in (try? partial.adding(row.amount)) ?? partial }
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			if isNaming {
				namingHeader
			} else {
				header
			}
			if expanded && !isNaming {
				Divider().background(Theme.Colors.borderDivider).padding(.leading, Theme.Spacing.lg)
				rows
				footer
			}
		}
		.background(Theme.Colors.card)
		.clipShape(.rect(cornerRadius: Theme.Radius.md))
		.opacity(group.isExcluded ? 0.45 : 1)
		.onChange(of: isNameFocused) { _, focused in
			if !focused { isNaming = false }
		}
		.swipeActions(edge: .trailing, allowsFullSwipe: false) {
			Button(role: group.isExcluded ? .cancel : .destructive) {
				onSetExcluded(!group.isExcluded)
			} label: {
				Label(
					group.isExcluded ? String(localized: "Include group") : String(localized: "Exclude group"),
					systemImage: group.isExcluded ? "tray.and.arrow.down" : "tray.and.arrow.up")
			}
		}
	}

	// MARK: - Folded

	private var header: some View {
		HStack(spacing: Theme.Spacing.md) {
			Button {
				isNaming = true
				isNameFocused = true
				onBeginNaming()
			} label: {
				VStack(alignment: .leading, spacing: 3) {
					Text(group.titleName.isEmpty ? String(localized: Lexicon.untitled) : group.titleName)
						.font(Theme.Typography.title16)
						.foregroundStyle(Theme.Colors.ink)
						.strikethrough(group.isExcluded)
						.lineLimit(2)
						.multilineTextAlignment(.leading)
					subtitle
				}
				.frame(maxWidth: .infinity, alignment: .leading)
				.contentShape(.rect)
			}
			.buttonStyle(.hapticPlain)
			.accessibilityLabel(Text(headerAccessibilityLabel))
			.accessibilityHint(Text(String(localized: "Renames this group")))

			Button {
				isExpanded = !expanded
			} label: {
				HStack(spacing: Theme.Spacing.md) {
					VStack(alignment: .trailing, spacing: 3) {
						Text(groupTotal.formatted())
							.font(Theme.Typography.title16)
							.foregroundStyle(Theme.Colors.ink)
							.monospacedDigit()
							.lineLimit(1)
						Text(countCaption)
							.font(Theme.Typography.caption12)
							.foregroundStyle(Theme.Colors.inkTertiary)
					}
					Image(systemName: expanded ? "chevron.down" : "chevron.right")
						.font(Theme.Typography.caption12)
						.foregroundStyle(Theme.Colors.inkQuaternary)
				}
				.contentShape(.rect)
			}
			.buttonStyle(.hapticPlain)
			.layoutPriority(1)
			.accessibilityLabel(Text("\(groupTotal.formatted()). \(countCaption)"))
			.accessibilityHint(Text(expanded ? String(localized: "Collapses this group") : String(localized: "Shows this group\u{2019}s rows")))
		}
		.padding(Theme.Spacing.lg)
	}

	/// The raw detail earns its line only when it differs from the name the
	/// rows will be saved under — otherwise it is the same string twice.
	@ViewBuilder private var subtitle: some View {
		if group.isExcluded {
			Text(String(localized: "Excluded — swipe to include"))
				.font(Theme.Typography.caption12)
				.foregroundStyle(Theme.Colors.inkTertiary)
		} else if group.rawDetail.localizedCaseInsensitiveCompare(group.titleName) != .orderedSame {
			HStack(spacing: Theme.Spacing.s6) {
				if group.rememberAlias {
					Image(systemName: "bookmark")
						.font(Theme.Typography.micro10)
						.foregroundStyle(Theme.Colors.inkTertiary)
				}
				Text(group.rawDetail)
					.font(Theme.Typography.caption12)
					.foregroundStyle(Theme.Colors.inkTertiary)
					.lineLimit(1)
			}
		}
	}

	private var countCaption: String {
		let included = includedRows.count
		let total = group.rows.count
		return included == total
			? String(localized: "\(total) expenses")
			: String(localized: "\(included) of \(total) included")
	}

	private var headerAccessibilityLabel: String {
		[group.titleName, group.rawDetail, groupTotal.formatted(), countCaption]
			.filter { !$0.isEmpty }
			.joined(separator: ". ")
	}

	// MARK: - Naming

	/// Naming replaces the header rather than pushing it down: the dropdown
	/// needs the room, and while naming there is nothing else to decide.
	private var namingHeader: some View {
		VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
			Text(group.rawDetail)
				.font(Theme.Typography.caption12)
				.foregroundStyle(Theme.Colors.textSubtle)
				.lineLimit(1)

			HStack(spacing: Theme.Spacing.sm) {
				TextField(String(localized: Lexicon.Term.singular.text), text: Binding(get: { group.titleName }, set: onRename))
					.font(Theme.Typography.body17)
					.foregroundStyle(Theme.Colors.ink)
					.textFieldStyle(.plain)
					.tint(Theme.Colors.accent)
					.focused($isNameFocused)
					.submitLabel(.done)
					.onSubmit { isNameFocused = false }

				// The field arrives pre-filled with the parsed merchant, and
				// renaming means replacing all of it — without this the user
				// backspaces through twenty-odd characters first.
				if !group.titleName.isEmpty {
					Button {
						onRename("")
					} label: {
						Image(systemName: "xmark.circle.fill")
							.font(Theme.Typography.body14)
							.foregroundStyle(Theme.Colors.inkQuaternary)
					}
					.buttonStyle(.hapticPlain)
					.accessibilityLabel(String(localized: "Clear name"))
				}
			}
				.padding(.horizontal, Theme.Spacing.lg)
				.frame(height: 56)
				.background(Theme.Colors.card)
				.clipShape(.rect(cornerRadius: Theme.Radius.md))
				.overlay {
					RoundedRectangle(cornerRadius: Theme.Radius.md)
						.stroke(Theme.Colors.accent, lineWidth: 1.5)
				}

			if !suggestions.isEmpty || isNewName {
				TitleSuggestionList(
					suggestions: suggestions,
					selectedID: group.existingTitleID,
					limitsByTitleID: limitsByTitleID,
					createName: isNewName ? group.titleName : nil,
					onSelect: { title in
						onSelectExisting(title)
						isNameFocused = false
					},
					onCreate: { isNameFocused = false }
				)
			}

			rememberAliasRow
		}
		.padding(Theme.Spacing.lg)
	}

	private var rememberAliasRow: some View {
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
	}

	private var rememberAliasText: String {
		group.rememberAlias
			? String(localized: "\(group.rawDetail) will be saved as \(group.titleName) from now on.")
			: String(localized: "Saved as \(group.titleName) — from a previous import.")
	}

	// MARK: - Opened

	private var rows: some View {
		ForEach(group.rows) { row in
			ImportRowCard(
				row: row,
				titleName: group.titleName,
				groupRawDetail: group.rawDetail,
				onToggleIncluded: { onToggleRow(row.id, $0) },
				onTap: { onTapRow(row) },
				onDelete: { onDeleteRow(row.id) }
			)
			if row.id != group.rows.last?.id {
				Divider().background(Theme.Colors.borderDivider).padding(.leading, Theme.Spacing.s42)
			}
		}
	}

	private var footer: some View {
		VStack(alignment: .leading, spacing: 0) {
			Divider().background(Theme.Colors.borderDivider).padding(.leading, Theme.Spacing.lg)
			HStack(spacing: Theme.Spacing.lg) {
				Button(String(localized: "Add row"), systemImage: "plus") {
					onAddRow()
				}
				.font(Theme.Typography.caption13Strong)
				.foregroundStyle(Theme.Colors.accent)
				.buttonStyle(.hapticPlain)

				Spacer()

				Button(group.isExcluded ? String(localized: "Include group") : String(localized: "Exclude group")) {
					onSetExcluded(!group.isExcluded)
				}
				.font(Theme.Typography.caption12)
				.foregroundStyle(Theme.Colors.danger)
				.buttonStyle(.hapticPlain)
			}
			.padding(.horizontal, Theme.Spacing.lg)
			.padding(.vertical, Theme.Spacing.md)
		}
	}
}
