//
//  Shadow+Theme.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

struct ShadowToken {
	let color: Color
	let radius: CGFloat
	let x: CGFloat
	let y: CGFloat
}

extension Theme {
	enum Shadow {
		static let subtle = ShadowToken(
			color: Color.black.opacity(0.06), radius: 2, x: 0, y: 1)

		static let cardSubtle = ShadowToken(
			color: Color.black.opacity(0.06), radius: 2, x: 0, y: 1)

		static let cardElevated = ShadowToken(
			color: Color(red: 0.043, green: 0.043, blue: 0.047).opacity(0.22),
			radius: 40, x: 0, y: 40)

		static let accentCTA = ShadowToken(
			color: Theme.Colors.accent.opacity(0.42), radius: 12, x: 0, y: 8)

		static let dropdown = ShadowToken(
			color: Color(red: 0.043, green: 0.043, blue: 0.047).opacity(0.22),
			radius: 16, x: 0, y: 8)

		static let focusGlow = ShadowToken(
			color: Theme.Colors.accent.opacity(0.12), radius: 4, x: 0, y: 0)

		static let qrAccentGlow = ShadowToken(
			color: Theme.Colors.accent.opacity(0.45), radius: 50, x: 0, y: -18)
	}
}

extension View {
	func shadow(_ token: ShadowToken) -> some View {
		shadow(color: token.color, radius: token.radius, x: token.x, y: token.y)
	}
}
