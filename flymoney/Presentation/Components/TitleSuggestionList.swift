//
//  TitleSuggestionList.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-08-28.
//

import SwiftUI

/// The suggestion rows shared by the Add screen's autocomplete and the import
/// review screen's category field. Extracted rather than duplicated: two
/// lookalike lists drift, and the whole point of the import field is that
/// naming a category feels the same in both places.
struct TitleSuggestionList: View {
	let suggestions: [ExpenseTitle]
	/// Drives the highlighted row and, with `selectedSummary`, its budget caption.
	let selectedID: UUID?
	let selectedSummary: MonthSummary?
	let limitsByTitleID: [UUID: Money]
	/// A trailing row that creates a title under this exact name. `nil` on the
	/// Add screen, where saving creates the title by name anyway.
	let createName: String?
	let onSelect: (ExpenseTitle) -> Void
	let onCreate: (() -> Void)?

	private let rowHeight: CGFloat = 52
	private let maxVisibleRows = 4

	init(
		suggestions: [ExpenseTitle],
		selectedID: UUID? = nil,
		selectedSummary: MonthSummary? = nil,
		limitsByTitleID: [UUID: Money] = [:],
		createName: String? = nil,
		onSelect: @escaping (ExpenseTitle) -> Void,
		onCreate: (() -> Void)? = nil
	) {
		self.suggestions = suggestions
		self.selectedID = selectedID
		self.selectedSummary = selectedSummary
		self.limitsByTitleID = limitsByTitleID
		self.createName = createName
		self.onSelect = onSelect
		self.onCreate = onCreate
	}

	var body: some View {
		let rowCount = suggestions.count + (createName == nil ? 0 : 1)
		let contentHeight = CGFloat(rowCount) * rowHeight + CGFloat(max(0, rowCount - 1))
		let cappedHeight = min(contentHeight, CGFloat(maxVisibleRows) * rowHeight)

		ScrollView {
			VStack(spacing: 0) {
				ForEach(suggestions) { title in
					TitleSuggestionRow(
						title: title,
						isSelected: title.id == selectedID,
						summary: title.id == selectedID ? selectedSummary : nil,
						limit: limitsByTitleID[title.id]
					) {
						onSelect(title)
					}
					if title.id != suggestions.last?.id || createName != nil {
						Divider().background(Theme.Colors.borderDivider)
					}
				}
				if let createName, let onCreate {
					CreateTitleRow(name: createName, action: onCreate)
				}
			}
		}
		.frame(height: cappedHeight)
		.scrollBounceBehavior(.basedOnSize)
		.scrollDismissesKeyboard(.immediately)
		.background(Theme.Colors.card)
		.clipShape(.rect(cornerRadius: Theme.Radius.md))
		.overlay {
			RoundedRectangle(cornerRadius: Theme.Radius.md)
				.stroke(Theme.Colors.borderHairline, lineWidth: 1)
		}
		.shadow(Theme.Shadow.dropdown)
	}
}

/// One existing title. The trailing caption answers "how much room is left in
/// this one?" — the selected row shows its month summary, an unselected one
/// its monthly limit, and a title without a limit says so.
struct TitleSuggestionRow: View {
	let title: ExpenseTitle
	let isSelected: Bool
	let summary: MonthSummary?
	let limit: Money?
	let onTap: () -> Void

	var body: some View {
		Button(action: onTap) {
			HStack {
				Text(title.name)
					.font(isSelected ? Theme.Typography.title16 : Theme.Typography.body16)
					.foregroundStyle(isSelected ? Theme.Colors.ink : Theme.Colors.inkSecondary)
					.lineLimit(1)
				Spacer()
				trailingCaption
			}
			.padding(.horizontal, Theme.Spacing.lg)
			.frame(height: 52)
			.background(isSelected ? Theme.Colors.accentTint : Color.clear)
			.contentShape(.rect)
		}
		.buttonStyle(.hapticPlain)
	}

	@ViewBuilder private var trailingCaption: some View {
		if isSelected, let summary, let remaining = summary.remaining {
			Text(summary.isOver
				 ? String(localized: "Over \(Money(minorUnits: abs(remaining.minorUnits), currencyCode: remaining.currencyCode).formatted())")
				 : String(localized: "Left \(remaining.formatted())"))
				.font(Theme.Typography.caption13Strong)
				.foregroundStyle(summary.isOver ? Theme.Colors.danger : Theme.Colors.success)
				.monospacedDigit()
		} else if let limit {
			Text("\(limit.formatted()) / \(String(localized: "mo"))")
				.font(Theme.Typography.body13)
				.foregroundStyle(Theme.Colors.textSubtle)
				.monospacedDigit()
		} else {
			Text(String(localized: "no limit"))
				.font(Theme.Typography.body13)
				.foregroundStyle(Theme.Colors.textPlaceholder)
		}
	}
}

/// Offered when what the user typed matches no existing title — the import
/// screen's way of saying "this really is a new one", rather than leaving them
/// wondering whether the name took.
private struct CreateTitleRow: View {
	let name: String
	let action: () -> Void

	var body: some View {
		Button(action: action) {
			HStack(spacing: Theme.Spacing.sm) {
				Image(systemName: "plus")
					.font(Theme.Typography.caption13Strong)
					.foregroundStyle(Theme.Colors.ink)
				Text(String(localized: Lexicon.createNamed(name)))
					.font(Theme.Typography.title16)
					.foregroundStyle(Theme.Colors.ink)
					.lineLimit(1)
				Spacer()
			}
			.padding(.horizontal, Theme.Spacing.lg)
			.frame(height: 52)
			.contentShape(.rect)
		}
		.buttonStyle(.hapticPlain)
	}
}
