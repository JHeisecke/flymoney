//
//  HapticsManager.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-30.
//

import UIKit

@MainActor
final class HapticsManager: HapticsFeedback {
	private var isEnabled: Bool
	private let impact = UIImpactFeedbackGenerator(style: .light)
	private let selection = UISelectionFeedbackGenerator()
	private let notification = UINotificationFeedbackGenerator()

	init(isEnabled: Bool = true) {
		self.isEnabled = isEnabled
	}

	func tap() {
		guard isEnabled else { return }
		impact.impactOccurred()
	}

	func selection() {
		guard isEnabled else { return }
		selection.selectionChanged()
	}

	func success() {
		guard isEnabled else { return }
		notification.notificationOccurred(.success)
	}

	func warning() {
		guard isEnabled else { return }
		notification.notificationOccurred(.warning)
	}

	func error() {
		guard isEnabled else { return }
		notification.notificationOccurred(.error)
	}

	func prepare() {
		guard isEnabled else { return }
		impact.prepare()
		selection.prepare()
		notification.prepare()
	}
}
