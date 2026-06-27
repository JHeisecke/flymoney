//
//  ShareStatusCaption.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

struct ShareStatusCaption: View {
	let phase: SharingViewModel.Phase

	var body: some View {
		HStack(spacing: Theme.Spacing.sm) {
			statusIcon
			Text(statusText)
				.font(Theme.Typography.body)
				.foregroundStyle(Theme.Colors.ink)
		}
	}

	@ViewBuilder
	private var statusIcon: some View {
		switch phase {
		case .done:
			Image(systemName: "checkmark.circle.fill")
				.foregroundStyle(Theme.Colors.success)
		case .failed:
			Image(systemName: "exclamationmark.triangle.fill")
				.foregroundStyle(Theme.Colors.danger)
		default:
			ProgressView()
				.scaleEffect(0.8)
		}
	}

	private var statusText: String {
		switch phase {
		case .idle: String(localized: "Waiting for receiver…")
		case .handshaking: String(localized: "Connecting…")
		case .sending(let p): String(localized: "Sending… \(Int(p * 100))%%")
		case .receiving(let p): String(localized: "Receiving… \(Int(p * 100))%%")
		case .done: String(localized: "Sent ✓")
		case .failed(let r): r
		case .awaitingMerge: "Ready to merge"
		case .saving: "Saving…"
		}
	}
}
