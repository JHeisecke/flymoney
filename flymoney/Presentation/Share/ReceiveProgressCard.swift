//
//  ReceiveProgressCard.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

struct ReceiveProgressCard: View {
	let phase: SharingViewModel.Phase
	let monthName: String

	var body: some View {
		VStack(spacing: Theme.Spacing.md) {
			HStack {
				PulsingDot(color: Theme.Colors.success, withRing: false)
				Text("Receiving \(monthName)")
					.font(Theme.Typography.title17)
					.foregroundStyle(Color.white)
				Spacer()
				Text(percentText)
					.font(Theme.Typography.body13)
					.foregroundStyle(Theme.Colors.inkQuaternary)
					.monospacedDigit()
			}
			progressBar
			HStack {
				Text(String(localized: "from iPhone · encrypted"))
					.font(Theme.Typography.caption12)
					.foregroundStyle(Theme.Colors.inkQuaternary)
				Spacer()
			}
		}
		.padding(Theme.Spacing.lg)
		.background(Theme.Colors.card)
		.clipShape(.rect(cornerRadius: Theme.Radius.lg))
		.overlay {
			RoundedRectangle(cornerRadius: Theme.Radius.lg)
				.stroke(Theme.Colors.borderSubtle, lineWidth: 1)
		}
	}

	private var progressBar: some View {
		GeometryReader { geo in
			ZStack(alignment: .leading) {
				RoundedRectangle(cornerRadius: 4)
					.fill(Theme.Colors.borderSubtle)
				RoundedRectangle(cornerRadius: 4)
					.fill(Theme.Colors.accent)
					.frame(width: geo.size.width * progress)
			}
		}
		.frame(height: 6)
	}

	private var progress: Double {
		if case .receiving(let p) = phase { return p }
		return 0
	}

	private var percentText: String {
		"\(Int(progress * 100))%"
	}
}
