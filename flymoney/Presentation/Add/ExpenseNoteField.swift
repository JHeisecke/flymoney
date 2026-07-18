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
    @FocusState var isFocused: Bool

	var body: some View {
		Group {
			if isExpanded {
				TextField(String(localized: "Add Note"), text: $text, axis: .vertical)
					.font(Theme.Typography.body13)
					.foregroundStyle(Theme.Colors.inkSecondary)
					.tint(Theme.Colors.accent)
					.textFieldStyle(.plain)
					.lineLimit(1...4)
			} else {
				Button {
					withAnimation(.easeOut(duration: 0.15)) { isExpanded = true }
				} label: {
					Text(String(localized: "Add Note"))
						.font(Theme.Typography.body13)
						.foregroundStyle(Theme.Colors.textSubtle)
				}
				.buttonStyle(.hapticPlain)
			}
		}
		.onAppear {
			if !text.isEmpty { isExpanded = true }
		}
	}
}
