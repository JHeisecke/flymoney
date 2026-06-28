//
//  SegmentedToggle.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

struct SegmentedToggle: View {
	@Binding var resolution: MergeResolution?
	let localName: String
	let localTitleID: UUID

	var body: some View {
		HStack(spacing: 0) {
			Button {
				resolution = .keepSeparate
			} label: {
				Text(String(localized: "Keep separate"))
					.font(Theme.Typography.body13)
					.frame(maxWidth: .infinity)
			}
			.buttonStyle(.plain)
			.foregroundStyle(resolution == .keepSeparate ? Theme.Colors.accent : Theme.Colors.inkSecondary)
			.padding(.vertical, Theme.Spacing.sm)
			.background(resolution == .keepSeparate ? Theme.Colors.card : Color.clear)
			.clipShape(.rect(cornerRadius: Theme.Radius.pillSm))

			Button {
				resolution = .mergeInto(localTitleID: localTitleID)
			} label: {
				Text("Merge → \(localName)")
					.font(Theme.Typography.body13)
					.frame(maxWidth: .infinity)
			}
			.buttonStyle(.plain)
			.foregroundStyle(resolution == .mergeInto(localTitleID: localTitleID) ? Theme.Colors.textOnAccent : Theme.Colors.inkSecondary)
			.padding(.vertical, Theme.Spacing.sm)
			.background(resolution == .mergeInto(localTitleID: localTitleID) ? Theme.Colors.accent : Color.clear)
			.clipShape(.rect(cornerRadius: Theme.Radius.pillSm))
		}
		.frame(height: 38)
		.padding(3)
		.background(Theme.Colors.segmentedTrack)
		.clipShape(.rect(cornerRadius: Theme.Radius.pillSm))
	}
}
