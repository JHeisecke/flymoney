//
//  ExpenseRowView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

struct ExpenseRowView: View {
	let row: HistoryRow

	var body: some View {
		HStack(spacing: Theme.Spacing.md) {
			Text(row.titleName)
				.font(Theme.Typography.body)
				.foregroundStyle(Theme.Colors.ink)
				.frame(maxWidth: .infinity, alignment: .leading)
			Text(row.amount.formatted())
				.font(Theme.Typography.bodyMedium)
				.foregroundStyle(Theme.Colors.ink)
				.monospacedDigit()
		}
		.padding(.vertical, Theme.Spacing.sm)
		.accessibilityElement(children: .combine)
	}
}
