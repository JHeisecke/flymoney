//
//  FirstExpenseHelpCard.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-13.
//

import SwiftUI

struct FirstExpenseHelpCard: View {
	let onDismiss: () -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
			Label("Your first expense", systemImage: "lightbulb")
				.font(.subheadline.bold())
			Text("Enter an amount. Choose a category or type a new name to create it when you save.")
				.font(.subheadline)
				.fixedSize(horizontal: false, vertical: true)
			Button("Hide this tip", action: onDismiss)
				.font(.subheadline.bold())
				.frame(minHeight: 44)
				.buttonStyle(.hapticPlain)
		}
		.foregroundStyle(Theme.Colors.inkSecondary)
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(Theme.Spacing.lg)
		.background(Theme.Colors.card, in: .rect(cornerRadius: Theme.Radius.md))
		.overlay {
			RoundedRectangle(cornerRadius: Theme.Radius.md)
				.strokeBorder(Theme.Colors.borderSubtle, lineWidth: 1)
		}
		.accessibilityElement(children: .contain)
	}
}
