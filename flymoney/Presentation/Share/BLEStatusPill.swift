//
//  BLEStatusPill.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

struct BLEStatusPill: View {
	let phase: SharingViewModel.Phase

	var body: some View {
		HStack(spacing: 9) {
			PulsingDot(color: Theme.Colors.accent, withRing: true)
			Text(String(localized: "Bluetooth · advertising"))
				.font(Theme.Typography.body13)
				.foregroundStyle(Color(white: 0.9))
			Rectangle()
				.fill(Theme.Colors.borderSubtle)
				.frame(width: 1, height: 14)
			Text(statusText)
				.font(Theme.Typography.body13)
				.foregroundStyle(Theme.Colors.inkQuaternary)
		}
		.padding(.horizontal, Theme.Spacing.s18)
		.frame(height: 38)
		.background(Theme.Colors.card)
		.clipShape(.rect(cornerRadius: Theme.Radius.pillMd))
		.overlay {
			RoundedRectangle(cornerRadius: Theme.Radius.pillMd)
				.stroke(Theme.Colors.borderSubtle, lineWidth: 1)
		}
	}

	private var statusText: String {
		switch phase {
		case .idle, .handshaking: String(localized: "Waiting for receiver")
		case .sending(let p): String(localized: "Sending… \(Int(p * 100))%")
		case .done: String(localized: "Sent ✓")
		case .failed(let r): r
		default: String(localized: "Waiting for receiver")
		}
	}
}
