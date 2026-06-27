//
//  TitleRowView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

struct TitleRowView: View {
	let title: ExpenseTitle

	var body: some View {
		HStack(spacing: Theme.Spacing.md) {
			VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
				Text(title.name)
					.font(Theme.Typography.bodyMedium)
					.foregroundStyle(Theme.Colors.ink)
				if let limit = title.limit {
					Text(limit.formatted())
						.font(Theme.Typography.caption)
						.foregroundStyle(Theme.Colors.textSecondary)
				} else {
					Text(String(localized: "No limit"))
						.font(Theme.Typography.caption)
						.foregroundStyle(Theme.Colors.textTertiary)
				}
			}
			Spacer()
			Image(systemName: "chevron.right")
				.font(.caption)
				.foregroundStyle(Theme.Colors.textTertiary)
		}
		.padding(.vertical, Theme.Spacing.sm)
		.accessibilityElement(children: .combine)
	}
}
