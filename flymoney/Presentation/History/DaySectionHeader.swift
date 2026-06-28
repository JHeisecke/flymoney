//
//  DaySectionHeader.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

struct DaySectionHeader: View {
	let label: String

	var body: some View {
		Text(label)
			.font(Theme.Typography.eyebrow11)
			.textCase(.uppercase)
			.tracking(1.5)
			.foregroundStyle(Theme.Colors.textPlaceholder)
			.frame(maxWidth: .infinity, alignment: .leading)
			.padding(.horizontal, Theme.Spacing.xxl)
			.padding(.bottom, Theme.Spacing.xs)
	}
}
