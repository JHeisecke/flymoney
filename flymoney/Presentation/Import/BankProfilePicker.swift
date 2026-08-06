//
//  BankProfilePicker.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-08-06.
//

import SwiftUI
import StatementParsing

/// Manual kind/profile override. Grouped by `bankID` — `displayName` names a
/// *layout* ("Extracto de tarjeta"), `bankID` names the *institution*, so
/// three GNB profiles appear under one bank rather than as three siblings.
struct BankProfilePicker: View {
	let profiles: [StatementProfile]
	let onSelect: (StatementProfile) -> Void
	let onCancel: () -> Void

	private var groupedByBank: [(bankID: String, profiles: [StatementProfile])] {
		let grouped = Dictionary(grouping: profiles, by: \.bankID)
		return grouped.keys.sorted().map { ($0, grouped[$0] ?? []) }
	}

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
					ForEach(groupedByBank, id: \.bankID) { bank in
						VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
							Text(bank.bankID.uppercased())
								.font(Theme.Typography.eyebrow12)
								.foregroundStyle(Theme.Colors.textSubtle)
							VStack(spacing: 0) {
								ForEach(bank.profiles) { profile in
									Button {
										onSelect(profile)
									} label: {
										HStack {
											Text(profile.displayName)
												.font(Theme.Typography.body16)
												.foregroundStyle(Theme.Colors.ink)
											Spacer()
											Image(systemName: "chevron.right")
												.font(Theme.Typography.caption12)
												.foregroundStyle(Theme.Colors.inkQuaternary)
										}
										.padding(.horizontal, Theme.Spacing.lg)
										.frame(height: 52)
										.contentShape(.rect)
									}
									.buttonStyle(.hapticPlain)
									if profile.id != bank.profiles.last?.id {
										Divider().background(Theme.Colors.borderDivider)
									}
								}
							}
							.background(Theme.Colors.card)
							.clipShape(.rect(cornerRadius: Theme.Radius.md))
						}
					}
				}
				.padding(Theme.Spacing.xxl)
			}
			.background(Theme.Colors.surface)
			.navigationTitle(Text(String(localized: "Choose bank")))
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					Button {
						onCancel()
					} label: {
						Image(systemName: "xmark")
							.foregroundStyle(Theme.Colors.textSubtle)
					}
					.buttonStyle(.hapticPlain)
					.accessibilityLabel(String(localized: "Cancel"))
				}
			}
			.tint(Theme.Colors.accent)
		}
	}
}
