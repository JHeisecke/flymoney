//
//  PulsingDot.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

struct PulsingDot: View {
	var color: Color = Theme.Colors.success
	var withRing: Bool = false

	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var phase = false

	var body: some View {
		ZStack {
			if withRing && !reduceMotion {
				Circle()
					.fill(color)
					.opacity(phase ? 0 : 0.5)
					.scaleEffect(phase ? 2.1 : 0.7)
					.animation(.easeOut(duration: 1.8).repeatForever(autoreverses: false), value: phase)
			}
			Circle()
				.fill(color)
				.opacity(reduceMotion ? 1 : (phase ? 0.35 : 1))
				.scaleEffect(reduceMotion ? 1 : (phase ? 0.82 : 1))
				.animation(reduceMotion ? nil : .easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: phase)
		}
		.frame(width: 9, height: 9)
		.onAppear { phase.toggle() }
	}
}
