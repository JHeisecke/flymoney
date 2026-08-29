//
//  TitleAutocompleteField.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

struct TitleAutocompleteField: View {
    
    @State private var showAllTitles = false

	@Binding var titleName: String
	@Binding var showSuggestions: Bool
	let suggestions: [ExpenseTitle]
	let selectedID: UUID?
	let selectedSummary: MonthSummary?
	let limitsByTitleID: [UUID: Money]
	let assembly: AppAssembly
	let onQueryChange: (String) -> Void
	let onSelect: (ExpenseTitle) async -> Void

	@FocusState private var isFocused: Bool

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
            .sheet(isPresented: $showAllTitles) {
                AllTitlesManagementView(
                    viewModel: assembly.makeAllTitlesManagementViewModel(),
                    onSelect: { title in
                        titleName = title.name
                        showAllTitles = false
                        Task { await onSelect(title) }
                    })
            }
	}

	private var field: some View {
		ZStack(alignment: .trailing) {
			TextField("", text: $titleName)
				.font(Theme.Typography.body17)
				.tint(Theme.Colors.accent)
				.focused($isFocused)
				.textFieldStyle(.plain)
			if titleName.isEmpty {
                Button {
                    showAllTitles = true
                } label: {
                    EyebrowLabel(text: Lexicon.Term.singular.text, tracking: 0.6)
                        .padding(.trailing, Theme.Spacing.s14)
                }
                .buttonStyle(.hapticPlain)
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
		.onChange(of: titleName) { _, newValue in
			if isFocused { showSuggestions = true }
			onQueryChange(newValue)
		}
	}

	private var dropdown: some View {
		TitleSuggestionList(
			suggestions: suggestions,
			selectedID: selectedID,
			selectedSummary: selectedSummary,
			limitsByTitleID: limitsByTitleID
		) { title in
			showSuggestions = false
			isFocused = false
			Task { await onSelect(title) }
		}
	}
}
