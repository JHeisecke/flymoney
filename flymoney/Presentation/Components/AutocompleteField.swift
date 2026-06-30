//
//  AutocompleteField.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

struct AutocompleteField<Suggestion: Identifiable>: View {
	let label: LocalizedStringResource
	let placeholder: String
	@Binding var text: String
	let suggestions: [Suggestion]
	let suggestionLabel: (Suggestion) -> String
	let onQueryChange: (String) async -> Void
	let onSelect: (Suggestion) async -> Void
	var debounce: Duration = .milliseconds(200)

	@FocusState private var isFocused: Bool

	var body: some View {
		VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
			TextField(placeholder, text: $text)
				.font(Theme.Typography.body17)
				.tint(Theme.Colors.accent)
				.focused($isFocused)
				.textFieldStyle(.plain)
				.padding(.horizontal, Theme.Spacing.lg)
				.frame(height: 56)
				.background(Theme.Colors.card)
				.clipShape(.rect(cornerRadius: Theme.Radius.md))
				.overlay {
					RoundedRectangle(cornerRadius: Theme.Radius.md)
						.stroke(Theme.Colors.accent, lineWidth: 1.5)
				}
				.shadow(isFocused ? Theme.Shadow.focusGlow : Theme.Shadow.subtle)

			if isFocused, !suggestions.isEmpty {
				SuggestionListView(
					suggestions: suggestions,
					label: suggestionLabel,
					onSelect: onSelect
				)
				.padding(.top, Theme.Spacing.sm)
				.transition(.opacity)
			}
		}
		.task(id: text) {
			try? await Task.sleep(for: debounce)
			guard !Task.isCancelled else { return }
			await onQueryChange(text)
		}
	}
}

private struct SuggestionListView<Suggestion: Identifiable>: View {
	let suggestions: [Suggestion]
	let label: (Suggestion) -> String
	let onSelect: (Suggestion) async -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			ForEach(suggestions) { suggestion in
				Button {
					Task { await onSelect(suggestion) }
				} label: {
					Text(label(suggestion))
						.font(Theme.Typography.body16)
						.foregroundStyle(Theme.Colors.inkSecondary)
						.frame(maxWidth: .infinity, alignment: .leading)
						.padding(.horizontal, Theme.Spacing.lg)
						.frame(height: 52)
                        .contentShape(.rect)                        
				}
				.buttonStyle(.plain)
				if suggestion.id != suggestions.last?.id {
					Divider().background(Theme.Colors.borderDivider)
				}
			}
		}
		.background(Theme.Colors.card)
		.clipShape(.rect(cornerRadius: Theme.Radius.md))
		.overlay {
			RoundedRectangle(cornerRadius: Theme.Radius.md)
				.stroke(Theme.Colors.borderHairline, lineWidth: 1)
		}
		.shadow(Theme.Shadow.dropdown)
	}
}
