//
//  PillButton.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

enum PillButtonStyle { case filled, outline }

struct PillButton: View {
	let title: LocalizedStringResource
	let systemImage: String?
	var style: PillButtonStyle = .filled
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
			.background(style == .filled ? Theme.Colors.accent : Color.clear)
			.foregroundStyle(style == .filled ? Theme.Colors.textOnAccent : Theme.Colors.accent)
			.clipShape(.rect(cornerRadius: Theme.Radius.pillSm))
			.overlay {
				if style == .outline {
					RoundedRectangle(cornerRadius: Theme.Radius.pillSm)
						.stroke(Theme.Colors.accent, lineWidth: 1.5)
				}
			}
		}
		.buttonStyle(.hapticPlain)
	}
}
