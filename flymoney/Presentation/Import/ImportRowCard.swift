//
//  ImportRowCard.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-08-06.
//

import SwiftUI

/// One staged row. Four flags can co-occur and are shown independently —
/// never collapsed into one badge.
struct ImportRowCard: View {
	let row: EditableRow
	let onToggleIncluded: @Sendable (Bool) -> Void
	let onTap: () -> Void
	let onDelete: () -> Void

	var body: some View {
		Button(action: onTap) {
			HStack(alignment: .top, spacing: Theme.Spacing.md) {
				Toggle("", isOn: Binding(get: { row.isIncluded }, set: onToggleIncluded))
                    .tint(.accentTint) // TODO: Tint is not taking place
					.labelsHidden()
					.toggleStyle(.checkbox)
					.accessibilityLabel(row.isIncluded
						? String(localized: "Included in import")
						: String(localized: "Excluded from import"))

				VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
					Text(row.rawDetail)
						.font(Theme.Typography.body16)
						.foregroundStyle(row.isIncluded ? Theme.Colors.ink : Theme.Colors.inkQuaternary)
					Text(row.date.formatted(date: .abbreviated, time: .omitted))
						.font(Theme.Typography.caption12)
						.foregroundStyle(Theme.Colors.inkTertiary)
					flagCaptions
				}

				Spacer()

				Text(row.amount.formatted())
					.font(Theme.Typography.title16)
					.foregroundStyle(row.flags.isRefund ? Theme.Colors.success : (row.isIncluded ? Theme.Colors.ink : Theme.Colors.inkQuaternary))
					.monospacedDigit()
			}
			.padding(.vertical, Theme.Spacing.s14)
			.padding(.horizontal, Theme.Spacing.lg)
			.opacity(row.isIncluded ? 1 : 0.55)
			.contentShape(.rect)
		}
		.buttonStyle(.hapticPlain)
		.accessibilityElement(children: .combine)
		.accessibilityLabel(accessibilityLabel)
		.swipeActions(edge: .trailing) {
			Button(role: .destructive, action: onDelete) {
				Label(String(localized: "Delete"), systemImage: "trash")
			}
		}
	}

	@ViewBuilder private var flagCaptions: some View {
		if row.flags.alreadyImported {
			badge(String(localized: "Already imported"), color: Theme.Colors.textSubtle)
		}
		if let duplicate = row.flags.possibleDuplicate {
			badge(possibleDuplicateCaption(duplicate), color: Theme.Colors.warning)
		}
		if row.flags.isAmbiguous {
			badge(String(localized: "Can\u{2019}t tell if this was a payment or moving your own money."), color: Theme.Colors.warning)
		}
		if row.flags.isRefund {
			badge(String(localized: "Refund"), color: Theme.Colors.success)
		}
	}

	private func possibleDuplicateCaption(_ duplicate: PossibleDuplicate) -> String {
		duplicate.wasImported
			? String(localized: "Similar to \(duplicate.titleName), already imported")
			: String(localized: "Similar to \(duplicate.titleName), entered by hand")
	}

	private func badge(_ text: String, color: Color) -> some View {
		Text(text)
			.font(Theme.Typography.caption12)
			.foregroundStyle(color)
			.fixedSize(horizontal: false, vertical: true)
	}

	private var accessibilityLabel: Text {
		var parts: [String] = [row.amount.formatted(), row.rawDetail, row.date.formatted(date: .abbreviated, time: .omitted)]
		if row.flags.alreadyImported { parts.append(String(localized: "Already imported")) }
		if let duplicate = row.flags.possibleDuplicate { parts.append(possibleDuplicateCaption(duplicate)) }
		if row.flags.isAmbiguous { parts.append(String(localized: "Ambiguous")) }
		if row.flags.isRefund { parts.append(String(localized: "Refund")) }
		return Text(parts.joined(separator: ". "))
	}
}

private struct CheckboxToggleStyle: ToggleStyle {
	func makeBody(configuration: Configuration) -> some View {
		Button {
			configuration.isOn.toggle()
		} label: {
			Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "circle")
				.font(Theme.Typography.title17)
				.foregroundStyle(configuration.isOn ? Theme.Colors.accent : Theme.Colors.borderStrong)
		}
		.buttonStyle(.plain)
	}
}

extension ToggleStyle where Self == CheckboxToggleStyle {
	static var checkbox: CheckboxToggleStyle { CheckboxToggleStyle() }
}
