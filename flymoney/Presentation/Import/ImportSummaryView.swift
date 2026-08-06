//
//  ImportSummaryView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-08-06.
//

import SwiftUI

/// Post-commit result. The entry point is on Add, but the results live in
/// History and Titles — this offers a way through rather than dead-ending on
/// a form for entering one expense by hand.
struct ImportSummaryView: View {
	let result: StatementImportResult
	let refundCount: Int
	let onViewHistory: () -> Void
	let onDone: () -> Void

	var body: some View {
		VStack(spacing: Theme.Spacing.xl) {
			Spacer()

			Image(systemName: "checkmark.circle.fill")
				.font(.system(size: 56))
				.foregroundStyle(Theme.Colors.success)

			Text(headline)
				.font(Theme.Typography.title17)
				.multilineTextAlignment(.center)
				.foregroundStyle(Theme.Colors.ink)

			if result.months.count > 1 {
				VStack(spacing: Theme.Spacing.xs) {
					ForEach(result.months, id: \.self) { month in
						Text(monthLabel(month))
							.font(Theme.Typography.body14)
							.foregroundStyle(Theme.Colors.inkTertiary)
					}
				}
			}

			Spacer()

			PillButton(title: "View in History", systemImage: "list.bullet") {
				onViewHistory()
			}

			Button(String(localized: "Done")) {
				onDone()
			}
			.font(Theme.Typography.body14)
			.foregroundStyle(Theme.Colors.textSubtle)
			.buttonStyle(.hapticPlain)
		}
		.padding(Theme.Spacing.xxl)
		.background(Theme.Colors.surface)
	}

	private var headline: String {
		let titleCount = result.titlesCreated
		if refundCount > 0 {
			return String(localized: "\(result.expensesAdded) expenses added · \(titleCount) new categories · \(refundCount) refunds")
		}
		return String(localized: "\(result.expensesAdded) expenses added · \(titleCount) new categories")
	}

	private func monthLabel(_ month: CalendarMonth) -> String {
		month.interval(using: .current).start.formatted(.dateTime.month(.wide).year().locale(.current))
	}
}
