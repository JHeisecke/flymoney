//
//  MonthPickerHeader.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

struct MonthPickerHeader: View {
	@Binding var month: CalendarMonth
	let calendar: Calendar
	var onPrevious: () -> Void
	var onNext: () -> Void

	@State private var isPickerPresented = false

	var body: some View {
		HStack(spacing: Theme.Spacing.md) {
			Button {
				onPrevious()
			} label: {
				Label(String(localized: "Previous month"), systemImage: "chevron.left")
					.labelStyle(.iconOnly)
					.font(Theme.Typography.body)
					.padding(Theme.Spacing.sm)
			}
			.buttonStyle(.plain)

			Button {
				isPickerPresented = true
			} label: {
				Text(monthLabel)
					.font(Theme.Typography.title)
					.foregroundStyle(Theme.Colors.ink)
					.frame(maxWidth: .infinity)
			}
			.buttonStyle(.plain)
			.accessibilityHint(Text(String(localized: "Pick a different month")))

			Button {
				onNext()
			} label: {
				Label(String(localized: "Next month"), systemImage: "chevron.right")
					.labelStyle(.iconOnly)
					.font(Theme.Typography.body)
					.padding(Theme.Spacing.sm)
			}
			.buttonStyle(.plain)
		}
		.padding(.horizontal, Theme.Spacing.lg)
		.padding(.vertical, Theme.Spacing.md)
		.sheet(isPresented: $isPickerPresented) {
			MonthPickerSheet(month: $month, calendar: calendar)
				.presentationDetents([.medium])
		}
	}

	private var monthLabel: String {
		let interval = month.interval(using: calendar)
		return interval.start.formatted(
			.dateTime.month(.wide).year().locale(.current))
	}
}

private struct MonthPickerSheet: View {
	@Binding var month: CalendarMonth
	let calendar: Calendar

	@State private var date: Date

	init(month: Binding<CalendarMonth>, calendar: Calendar) {
		self._month = month
		self.calendar = calendar
		let interval = month.wrappedValue.interval(using: calendar)
		self._date = State(initialValue: interval.start)
	}

	var body: some View {
		NavigationStack {
			DatePicker(String(localized: "Pick a different month"),
					   selection: $date, displayedComponents: .date)
				.datePickerStyle(.graphical)
				.padding()
				.navigationTitle(String(localized: "Pick a different month"))
				.navigationBarTitleDisplayMode(.inline)
				.toolbar {
					ToolbarItem(placement: .topBarTrailing) {
						Button(String(localized: "Done")) {
							self.month = CalendarMonth.containing(date, using: calendar)
						}
					}
				}
		}
	}
}
