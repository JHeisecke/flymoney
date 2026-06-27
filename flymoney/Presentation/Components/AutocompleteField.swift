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
			Text(label)
				.font(Theme.Typography.caption)
				.foregroundStyle(Theme.Colors.textSecondary)

			TextField(placeholder, text: $text)
				.font(Theme.Typography.body)
				.textFieldStyle(.plain)
				.focused($isFocused)
				.padding(Theme.Spacing.md)
				.background(Theme.Colors.surface)
				.clipShape(.rect(cornerRadius: Theme.Radius.md))
				.overlay {
					RoundedRectangle(cornerRadius: Theme.Radius.md)
						.stroke(Theme.Colors.border, lineWidth: 1)
				}

			if isFocused, !suggestions.isEmpty {
				SuggestionListView(
					suggestions: suggestions,
					label: suggestionLabel,
					onSelect: onSelect
				)
				.padding(.top, Theme.Spacing.xs)
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
						.font(Theme.Typography.body)
						.foregroundStyle(Theme.Colors.ink)
						.frame(maxWidth: .infinity, alignment: .leading)
						.padding(Theme.Spacing.md)
				}
				.buttonStyle(.plain)
				if suggestion.id != suggestions.last?.id {
					Divider()
				}
			}
		}
		.background(Theme.Colors.surface)
		.clipShape(.rect(cornerRadius: Theme.Radius.md))
		.overlay {
			RoundedRectangle(cornerRadius: Theme.Radius.md)
				.stroke(Theme.Colors.border, lineWidth: 1)
		}
	}
}
