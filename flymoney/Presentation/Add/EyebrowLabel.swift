//
//  EyebrowLabel.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

struct EyebrowLabel: View {
	let text: LocalizedStringResource
	var tracking: CGFloat = 2

	var body: some View {
		Text(text)
			.font(Theme.Typography.eyebrow12)
			.textCase(.uppercase)
			.tracking(tracking)
			.foregroundStyle(Theme.Colors.textPlaceholder)
	}
}
