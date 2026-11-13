//
//  ExpenseNoteField.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-07-18.
//

import SwiftUI

struct ExpenseNoteField: View {
	@Binding var text: String
	@State private var isExpanded = false
	@FocusState private var isFocused: Bool

	var body: some View {
		Group {
			if isExpanded {
				VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
					Label("Add Note", systemImage: "note.text")
						.font(Theme.Typography.caption13Strong)
						.foregroundStyle(Theme.Colors.accent)
					TextField(String(localized: "Add Note"), text: $text, axis: .vertical)
						.font(Theme.Typography.body16)
						.foregroundStyle(Theme.Colors.ink)
						.tint(Theme.Colors.accent)
						.textFieldStyle(.plain)
						.lineLimit(1...4)
						.focused($isFocused)
				}
				.padding(Theme.Spacing.lg)
			} else {
				Button {
					withAnimation(.easeOut(duration: 0.15)) { isExpanded = true }
				} label: {
					HStack {
						Label("Add Note", systemImage: "note.text.badge.plus")
						Spacer(minLength: Theme.Spacing.sm)
						Image(systemName: "chevron.down")
							.accessibilityHidden(true)
					}
					.font(Theme.Typography.body16)
					.foregroundStyle(Theme.Colors.accent)
					.padding(.horizontal, Theme.Spacing.lg)
					.frame(minHeight: 48)
					.contentShape(.rect)
				}
				.buttonStyle(.hapticPlain)
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(Theme.Colors.accentTint)
		.clipShape(.rect(cornerRadius: Theme.Radius.md))
		.overlay {
			RoundedRectangle(cornerRadius: Theme.Radius.md)
				.strokeBorder(Theme.Colors.borderSubtle, lineWidth: 1)
		}
		.onAppear {
			if !text.isEmpty { isExpanded = true }
		}
		.onChange(of: isExpanded) { _, expanded in
			// Only the user's expand action requests focus, never tab reappearance
			// or displaying an existing note in the expense editor.
			if expanded, text.isEmpty { isFocused = true }
		}
		.onDisappear { isFocused = false }
	}
}
