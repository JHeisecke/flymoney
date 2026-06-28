//
//  PillButton.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

struct PillButton: View {
	let title: LocalizedStringResource
	let systemImage: String?
	let action: () -> Void

	var body: some View {
		Button(action: action) {
			HStack(spacing: Theme.Spacing.xs) {
				if let systemImage {
					Image(systemName: systemImage)
						.font(Theme.Typography.title17)
				}
				Text(title)
					.font(Theme.Typography.caption13Strong)
			}
			.padding(.horizontal, Theme.Spacing.s14)
			.frame(height: 34)
			.background(Theme.Colors.accent)
			.foregroundStyle(Theme.Colors.textOnAccent)
			.clipShape(.rect(cornerRadius: Theme.Radius.pillSm))
		}
		.buttonStyle(.plain)
	}
}
