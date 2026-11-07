//
//  GuideInstructions.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-07.
//

import SwiftUI

struct GuideInstructions: View {
	let symbolName: String
	let points: [LocalizedStringResource]

	var body: some View {
		VStack(alignment: .leading, spacing: Theme.Spacing.md) {
			Image(systemName: symbolName)
				.font(.title2.weight(.semibold))
				.foregroundStyle(Theme.Colors.ink)
				.padding(Theme.Spacing.md)
				.background(Theme.Colors.accentTint, in: .rect(cornerRadius: Theme.Radius.md))
				.accessibilityHidden(true)

			ForEach(points.indices, id: \.self) { index in
				HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
					Text(verbatim: "•")
						.accessibilityHidden(true)
					Text(points[index])
						.fixedSize(horizontal: false, vertical: true)
				}
			}
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding()
	}
}
