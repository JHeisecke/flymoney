//
//  MonthHeaderView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

struct MonthHeaderView: View {
	let month: CalendarMonth
	let calendar: Calendar
	let onPrevious: () -> Void
	let onNext: () -> Void

	var body: some View {
		HStack(spacing: Theme.Spacing.s18) {
			Button("Previous month", systemImage: "chevron.left") {
				onPrevious()
			}
			.labelStyle(.iconOnly)
			.foregroundStyle(Theme.Colors.inkQuaternary)

			Text(label)
				.font(Theme.Typography.title16)
				.foregroundStyle(Theme.Colors.inkSecondary)
				.contentTransition(.numericText())
				.animation(.default, value: month)

			Button("Next month", systemImage: "chevron.right") {
				onNext()
			}
			.labelStyle(.iconOnly)
			.foregroundStyle(Theme.Colors.inkSecondary)
		}
	}

	private var label: String {
		let interval = month.interval(using: calendar)
		return interval.start.formatted(
			.dateTime.month(.wide).year().locale(.current))
	}
}
