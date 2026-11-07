//
//  DateChipView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

struct DateChipView: View {
	@Binding var date: Date
	var isRecurring: Binding<Bool>? = nil

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
			.frame(minHeight: 44)

			if let isRecurring {
				RecurrenceChipButton(date: date, isRecurring: isRecurring)
			}
		}
		.popover(isPresented: $isPickerPresented, attachmentAnchor: .point(.bottom)) {
            DatePicker(
                String(localized: "Date"),
                selection: $date,
                in: ...Date.distantFuture,
                displayedComponents: .date
            )
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

private struct RecurrenceChipButton: View {
	let date: Date
	@Binding var isRecurring: Bool
	@AppStorage("hasSeenRecurringExpenseExplanation") private var hasSeenExplanation = false
	@AppStorage("recurringExpenseExplanationCount") private var explanationCount = 0
	@AppStorage("recurringExpenseExplanationFirstShownAt") private var firstShownTimestamp = 0.0
	@State private var isExplanationPresented = false

	var body: some View {
		Button {
			isRecurring.toggle()
			if isRecurring {
				var explanation = RecurrenceExplanationState(
					displayCount: explanationCount,
					firstShownAt: firstShownTimestamp > 0 ? Date(timeIntervalSince1970: firstShownTimestamp) : nil)
				isExplanationPresented = explanation.recordActivation(
					at: .now, calendar: .current, hasSeenLegacyExplanation: hasSeenExplanation)
				explanationCount = explanation.displayCount
				firstShownTimestamp = explanation.firstShownAt?.timeIntervalSince1970 ?? 0
				hasSeenExplanation = explanationCount > 0
			}
		} label: {
			Label("Recurring expense", systemImage: "arrow.clockwise")
				.labelStyle(.iconOnly)
				.font(.title2)
				.foregroundStyle(isRecurring ? Theme.Colors.accent : Theme.Colors.textSubtle)
				.frame(width: 44, height: 38)
				.background(isRecurring ? Theme.Colors.accentTint : Theme.Colors.card)
				.clipShape(.rect(cornerRadius: Theme.Radius.pillSm))
				.overlay {
					RoundedRectangle(cornerRadius: Theme.Radius.pillSm)
						.stroke(isRecurring ? Theme.Colors.accent : Theme.Colors.borderSubtle, lineWidth: 1)
				}
				.frame(minHeight: 44)
				.contentShape(.rect)
		}
		.buttonStyle(.hapticPlain)
		.accessibilityValue(isRecurring ? String(localized: "On") : String(localized: "Off"))
		.accessibilityAddTraits(isRecurring ? .isSelected : [])
		.alert("Recurring expense", isPresented: $isExplanationPresented) {
			Button("Got it", role: .cancel) { }
		} message: {
			Text("You’re about to mark this expense as recurring on \(date.formatted(date: .long, time: .omitted)). You can turn this option off by tapping the button again.")
		}
	}
}
