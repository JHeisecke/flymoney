//
//  TitleAutocompleteField.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

struct TitleAutocompleteField: View {
	@Bindable var form: AddExpenseFormModel
	@Binding var showSuggestions: Bool
	let suggestions: [ExpenseTitle]
	let selectedID: UUID?
	let selectedSummary: MonthSummary?
	let onQueryChange: (String) -> Void
	let onSelect: (ExpenseTitle) async -> Void

	@FocusState private var isFocused: Bool

	private let rowHeight: CGFloat = 52
	private let maxVisibleRows = 4
	private let fieldHeight: CGFloat = 56

	var body: some View {
		field
			.zIndex(1)
			.overlay(alignment: .topLeading) {
				if showSuggestions, !suggestions.isEmpty {
					dropdown
						.frame(maxWidth: .infinity)
						.offset(y: fieldHeight + Theme.Spacing.sm)
						.transition(.opacity)
				}
			}
			.onChange(of: isFocused) { _, focused in
				if focused { showSuggestions = true }
			}
	}

	private var field: some View {
		ZStack(alignment: .trailing) {
			TextField("", text: $form.titleName)
				.font(Theme.Typography.body17)
				.tint(Theme.Colors.accent)
				.focused($isFocused)
				.textFieldStyle(.plain)
			if form.titleName.isEmpty {
				EyebrowLabel(text: Lexicon.Term.singular.text, tracking: 0.6)
					.padding(.trailing, Theme.Spacing.s14)
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
		.shadow(isFocused ? Theme.Shadow.focusGlow : Theme.Shadow.subtle)
		.onChange(of: form.titleName) { _, newValue in
			showSuggestions = true
			onQueryChange(newValue)
		}
	}

	private var dropdown: some View {
		let count = suggestions.count
		let contentHeight = CGFloat(count) * rowHeight + CGFloat(max(0, count - 1))
		let cappedHeight = min(contentHeight, CGFloat(maxVisibleRows) * rowHeight)

		return ScrollView {
			VStack(spacing: 0) {
				ForEach(suggestions) { title in
					SuggestionRowView(
						title: title,
						isSelected: title.id == selectedID,
						summary: title.id == selectedID ? selectedSummary : nil
					) {
						showSuggestions = false
						isFocused = false
						Task { await onSelect(title) }
					}
					if title.id != suggestions.last?.id {
						Divider().background(Theme.Colors.borderDivider)
					}
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

private struct SuggestionRowView: View {
	let title: ExpenseTitle
	let isSelected: Bool
	let summary: MonthSummary?
	let onTap: () -> Void

	var body: some View {
		Button(action: onTap) {
			HStack {
				Text(title.name)
					.font(isSelected ? Theme.Typography.title16 : Theme.Typography.body16)
					.foregroundStyle(isSelected ? Theme.Colors.ink : Theme.Colors.inkSecondary)
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
		} else if let limit = title.limit {
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
