//
//  MonthHeaderView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

struct MonthHeaderView: View {
	@Binding var month: CalendarMonth
	let calendar: Calendar

	@State private var isPickerPresented = false

	var body: some View {
		Button {
			isPickerPresented = true
		} label: {
			Text(label)
				.font(Theme.Typography.title16)
				.foregroundStyle(Theme.Colors.inkSecondary)
		}
		.buttonStyle(.plain)
		.popover(isPresented: $isPickerPresented, attachmentAnchor: .point(.bottom)) {
			DatePicker(String(localized: "Month"), selection: anchorBinding, displayedComponents: .date)
				.datePickerStyle(.graphical)
				.padding(Theme.Spacing.lg)
				.presentationCompactAdaptation(.popover)
		}
	}

	private var label: String {
		let interval = month.interval(using: calendar)
		return interval.start.formatted(
			.dateTime.month(.wide).year().locale(.current))
	}

	private var anchorBinding: Binding<Date> {
		Binding(
			get: { month.interval(using: calendar).start },
			set: { newDate in
				month = CalendarMonth.containing(newDate, using: calendar)
			})
	}
}
