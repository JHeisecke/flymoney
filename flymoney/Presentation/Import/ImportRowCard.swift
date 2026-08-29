//
//  ImportRowCard.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-08-06.
//

import SwiftUI

/// One staged row inside an opened group. The row leads with the category it
/// will be saved under — renaming the group renames every row with it — and the
/// date sits below in a smaller, quieter type.
///
/// The parsed detail appears only when it differs from the group's own: within
/// a group it is otherwise the same string on every row, and the group header
/// already shows it.
///
/// Four flags can co-occur and are shown independently, never collapsed into
/// one badge. They render as chips here and as full sentences in
/// `ImportRowEditor`, where the decision is actually made; VoiceOver reads the
/// sentences either way.
struct ImportRowCard: View {
	let row: EditableRow
	/// The group's category name — what this row commits as.
	let titleName: String
	/// The group's parsed detail, to decide whether this row's own is worth showing.
	let groupRawDetail: String
	let onToggleIncluded: @Sendable (Bool) -> Void
	let onTap: () -> Void
	let onDelete: () -> Void

	var body: some View {
		Button(action: onTap) {
			HStack(alignment: .center, spacing: Theme.Spacing.md) {
				Toggle("", isOn: Binding(get: { row.isIncluded }, set: onToggleIncluded))
					.labelsHidden()
					.toggleStyle(.checkbox)
					.accessibilityLabel(row.isIncluded
						? String(localized: "Included in import")
						: String(localized: "Excluded from import"))

				VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
					VStack(alignment: .leading, spacing: 2) {
						Text(titleName.isEmpty ? row.rawDetail : titleName)
							.font(Theme.Typography.body16)
							.foregroundStyle(row.isIncluded ? Theme.Colors.ink : Theme.Colors.inkQuaternary)
							.lineLimit(2)
							.multilineTextAlignment(.leading)
						Text(dateAndDetail)
							.font(Theme.Typography.caption12)
							.foregroundStyle(Theme.Colors.inkQuaternary)
							.lineLimit(1)
					}
					flagChips
				}
				.frame(maxWidth: .infinity, alignment: .leading)

				Text(row.amount.formatted())
					.font(Theme.Typography.title16)
					.foregroundStyle(row.flags.isRefund ? Theme.Colors.success : (row.isIncluded ? Theme.Colors.ink : Theme.Colors.inkQuaternary))
					.monospacedDigit()
					.lineLimit(1)
					.layoutPriority(1)
			}
			.padding(.vertical, Theme.Spacing.md)
			.padding(.horizontal, Theme.Spacing.lg)
			.opacity(row.isIncluded ? 1 : 0.55)
			.contentShape(.rect)
		}
		.buttonStyle(.hapticPlain)
		.accessibilityElement(children: .combine)
		.accessibilityLabel(accessibilityLabel)
		// Not `.swipeActions`: these rows live inside a card, which is itself
		// one row of the list, and a swipe cannot nest inside a swipe. The
		// row editor carries the same Delete for anyone who never long-presses.
		.contextMenu {
			Button(row.isIncluded ? String(localized: "Exclude from import") : String(localized: "Include in import"),
				   systemImage: row.isIncluded ? "circle" : "checkmark.circle") {
				onToggleIncluded(!row.isIncluded)
			}
			Button(String(localized: "Delete"), systemImage: "trash", role: .destructive, action: onDelete)
		}
	}

	/// The date, plus this row's own detail when the parser read something
	/// different from the rest of the group — a split or wrapped line.
	private var dateAndDetail: String {
		let date = row.date.formatted(date: .abbreviated, time: .omitted)
		guard row.rawDetail.localizedCaseInsensitiveCompare(groupRawDetail) != .orderedSame,
			  !row.rawDetail.isEmpty else { return date }
		return "\(date) · \(row.rawDetail)"
	}

	@ViewBuilder private var flagChips: some View {
		if row.flags.alreadyImported || row.flags.possibleDuplicate != nil
			|| row.flags.isAmbiguous || row.flags.isRefund {
			HStack(spacing: Theme.Spacing.s6) {
				if row.flags.alreadyImported {
					chip(String(localized: "Already imported"), color: Theme.Colors.inkTertiary, background: Theme.Colors.neutralTint)
				}
				if let duplicate = row.flags.possibleDuplicate {
					switch DuplicateStrength.of(duplicate, groupTitleName: titleName) {
					case .sameCategory:
						chip(String(localized: "Already in \(duplicate.titleName)"), color: Theme.Colors.danger, background: Theme.Colors.dangerTint)
					case .otherCategory:
						chip(String(localized: "Possible duplicate"), color: Theme.Colors.warning, background: Theme.Colors.warningTint)
					}
				}
				if row.flags.isAmbiguous {
					chip(String(localized: "Payment or transfer?"), color: Theme.Colors.warning, background: Theme.Colors.warningTint)
				}
				if row.flags.isRefund {
					chip(String(localized: "Refund"), color: Theme.Colors.success, background: Theme.Colors.successTint)
				}
			}
		}
	}

	private func chip(_ text: String, color: Color, background: Color) -> some View {
		Text(text)
			.font(Theme.Typography.micro11)
			.foregroundStyle(color)
			.padding(.horizontal, Theme.Spacing.sm)
			.padding(.vertical, 3)
			.background(background)
			.clipShape(.rect(cornerRadius: Theme.Radius.pill))
			.fixedSize(horizontal: false, vertical: true)
	}

	private var accessibilityLabel: Text {
		var parts: [String] = [row.amount.formatted(), row.rawDetail, row.date.formatted(date: .abbreviated, time: .omitted)]
		if row.flags.alreadyImported { parts.append(String(localized: "Already imported")) }
		if let duplicate = row.flags.possibleDuplicate {
			parts.append(ImportRowFlagCopy.possibleDuplicate(duplicate, groupTitleName: titleName))
		}
		if row.flags.isAmbiguous { parts.append(ImportRowFlagCopy.ambiguous) }
		if row.flags.isRefund { parts.append(String(localized: "Refund")) }
		return Text(parts.joined(separator: ". "))
	}
}

/// How closely a `possibleDuplicate` matches the category the group commits as.
///
/// The parser matches on day and amount alone — it cannot know what the user
/// will call this merchant. So the strength is decided here, against the name
/// on screen, and it changes the moment the group is renamed: rename a group to
/// the category that already holds an identical expense and the hint hardens
/// from "similar to something of yours" into "you already have this one".
enum DuplicateStrength: Equatable {
	/// Same day, same amount, and the category this group will be saved under.
	case sameCategory
	/// Same day and amount, but the existing expense lives elsewhere. A hint —
	/// two unrelated purchases of the same amount on one day are ordinary.
	case otherCategory

	static func of(_ duplicate: PossibleDuplicate, groupTitleName: String) -> DuplicateStrength {
		let name = groupTitleName.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !name.isEmpty else { return .otherCategory }
		return duplicate.titleName.localizedCaseInsensitiveCompare(name) == .orderedSame
			? .sameCategory
			: .otherCategory
	}
}

/// The sentences the chips stand in for. Shared by the row's VoiceOver label
/// and `ImportRowEditor`, so a flag never means one thing in the list and
/// another in the editor.
enum ImportRowFlagCopy {
	static var ambiguous: String {
		String(localized: "Can\u{2019}t tell if this was a payment or moving your own money.")
	}

	static func possibleDuplicate(_ duplicate: PossibleDuplicate, groupTitleName: String) -> String {
		switch DuplicateStrength.of(duplicate, groupTitleName: groupTitleName) {
		case .sameCategory:
			return duplicate.wasImported
				? String(localized: "Already in \(duplicate.titleName) from an earlier import — same day, same amount.")
				: String(localized: "You entered this in \(duplicate.titleName) by hand — same day, same amount.")
		case .otherCategory:
			return duplicate.wasImported
				? String(localized: "Similar to \(duplicate.titleName), already imported")
				: String(localized: "Similar to \(duplicate.titleName), entered by hand")
		}
	}

	/// Every sentence that applies to these flags, in list order.
	static func sentences(for flags: RowFlags, groupTitleName: String) -> [String] {
		var out: [String] = []
		if flags.alreadyImported { out.append(String(localized: "This one is already in your history.")) }
		if let duplicate = flags.possibleDuplicate {
			out.append(possibleDuplicate(duplicate, groupTitleName: groupTitleName))
		}
		if flags.isAmbiguous { out.append(ambiguous) }
		return out
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
