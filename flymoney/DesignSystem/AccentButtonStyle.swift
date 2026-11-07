//
//  AccentButtonStyle.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-07.
//

import SwiftUI

struct AccentButtonStyle: ButtonStyle {
	@Environment(\.isEnabled) private var isEnabled

	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.font(.body.weight(.semibold))
			.multilineTextAlignment(.center)
			.foregroundStyle(isEnabled ? Theme.Colors.textOnAccent : Theme.Colors.inkTertiary)
			.padding(.horizontal, Theme.Spacing.lg)
			.padding(.vertical, Theme.Spacing.sm)
			.frame(minHeight: 44)
			.background(
				isEnabled ? Theme.Colors.accent : Theme.Colors.cardElevated,
				in: .rect(cornerRadius: Theme.Radius.sm)
			)
			.opacity(configuration.isPressed ? 0.8 : 1)
	}
}

extension ButtonStyle where Self == AccentButtonStyle {
	static var accentFilled: AccentButtonStyle { .init() }
}
