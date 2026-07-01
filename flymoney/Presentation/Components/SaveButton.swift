//
//  SaveButton.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

struct SaveButton: View {
	let title: LocalizedStringResource
	let isLoading: Bool
	let isDisabled: Bool
	let action: () -> Void

	var body: some View {
		Button(action: action) {
			Group {
				if isLoading {
					ProgressView()
						.tint(Theme.Colors.textOnAccent)
				} else {
					Text(title)
						.font(Theme.Typography.body17)
						.foregroundStyle(Theme.Colors.textOnAccent)
				}
			}
			.frame(maxWidth: .infinity)
			.frame(height: 58)
			.background(Theme.Colors.accent)
			.clipShape(.rect(cornerRadius: Theme.Radius.lg))
			.shadow(Theme.Shadow.accentCTA)
			.opacity(isDisabled ? 0.45 : 1)
		}
		.buttonStyle(.hapticPlain)
		.disabled(isDisabled || isLoading)
	}
}
