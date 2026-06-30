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
		HStack(alignment: .center) {
			VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
				Text(row.titleName)
					.font(Theme.Typography.body16)
					.foregroundStyle(Theme.Colors.ink)
				Text(row.date.formatted(date: .omitted, time: .shortened))
					.font(Theme.Typography.caption12)
					.foregroundStyle(Theme.Colors.inkTertiary)
			}
			Spacer()
			Text(row.amount.formatted())
				.font(Theme.Typography.title16)
				.foregroundStyle(Theme.Colors.ink)
				.monospacedDigit()
		}
		.padding(.vertical, Theme.Spacing.s14)
		.padding(.horizontal, Theme.Spacing.xxl)
		.background(Theme.Colors.card)
	}
}
