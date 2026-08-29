//
//  ShareConfirmationView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-08-28.
//

import SwiftUI

/// The share extension's entire UI. Without it the sheet renders blank for the
/// sub-second it takes to copy the file, which reads as a crash — that is
/// exactly how the missing launch was first reported.
///
/// The copy has to carry the wait: a share extension cannot open its host app
/// (`NSExtensionContext.open` is Today and iMessage only), so the file sits in
/// the inbox until flymoney is next opened.
struct ShareConfirmationView: View {
	enum Outcome {
		case added
		case failed
	}

	let outcome: Outcome

	var body: some View {
		VStack(spacing: 12) {
			Image(systemName: outcome == .added ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
				.font(.largeTitle)
				.foregroundStyle(outcome == .added ? Color.green : Color.orange)
			Text(title)
				.font(.headline)
				.multilineTextAlignment(.center)
			Text(message)
				.font(.subheadline)
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)
		}
		.padding(24)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.accessibilityElement(children: .combine)
	}

	private var title: String {
		switch outcome {
		case .added: String(localized: "Added to flymoney")
		case .failed: String(localized: "Couldn’t add this statement")
		}
	}

	private var message: String {
		switch outcome {
		case .added: String(localized: "Open the app to review it.")
		case .failed: String(localized: "Open flymoney and import the file from there.")
		}
	}
}

#Preview("Added") {
	ShareConfirmationView(outcome: .added)
}

#Preview("Failed") {
	ShareConfirmationView(outcome: .failed)
}
