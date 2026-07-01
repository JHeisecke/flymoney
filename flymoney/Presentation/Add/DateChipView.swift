//
//  DateChipView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

struct DateChipView: View {
	@Binding var date: Date

	@State private var isPickerPresented = false

	var body: some View {
		HStack(spacing: Theme.Spacing.md) {
			Button {
				isPickerPresented = true
			} label: {
				HStack(spacing: Theme.Spacing.sm) {
					Image(systemName: "calendar")
						.font(Theme.Typography.body13)
						.foregroundStyle(Theme.Colors.textSubtle)
					Text(label)
						.font(Theme.Typography.body14)
						.foregroundStyle(Theme.Colors.inkSecondary)
				}
				.padding(.horizontal, Theme.Spacing.s14)
				.frame(height: 38)
				.background(Theme.Colors.card)
				.clipShape(.rect(cornerRadius: Theme.Radius.pillSm))
				.overlay {
					RoundedRectangle(cornerRadius: Theme.Radius.pillSm)
						.stroke(Theme.Colors.borderSubtle, lineWidth: 1)
				}
			}
			.buttonStyle(.hapticPlain)
			if Calendar.current.isDateInToday(date) {
				Text(String(localized: "Tap to change date"))
					.font(Theme.Typography.body13)
					.foregroundStyle(Theme.Colors.textPlaceholder)
			}
		}
		.popover(isPresented: $isPickerPresented, attachmentAnchor: .point(.bottom)) {
			DatePicker(String(localized: "Date"), selection: $date, displayedComponents: .date)
				.datePickerStyle(.graphical)
				.frame(minWidth: 320)
				.padding(Theme.Spacing.lg)
				.presentationCompactAdaptation(.popover)
		}
	}

	private var label: String {
		let cal = Calendar.current
		if cal.isDateInToday(date) { return String(localized: "Today") }
		if cal.isDateInYesterday(date) { return String(localized: "Yesterday") }
		return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
	}
}
