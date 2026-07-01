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
	private let impactGenerator = UIImpactFeedbackGenerator(style: .light)
	private let selectionGenerator = UISelectionFeedbackGenerator()
	private let notificationGenerator = UINotificationFeedbackGenerator()

	init(isEnabled: Bool = true) {
		self.isEnabled = isEnabled
	}

	func tap() {
		guard isEnabled else { return }
		impactGenerator.impactOccurred()
	}

	func selection() {
		guard isEnabled else { return }
		selectionGenerator.selectionChanged()
	}

	func success() {
		guard isEnabled else { return }
		notificationGenerator.notificationOccurred(.success)
	}

	func warning() {
		guard isEnabled else { return }
		notificationGenerator.notificationOccurred(.warning)
	}

	func error() {
		guard isEnabled else { return }
		notificationGenerator.notificationOccurred(.error)
	}

	func prepare() {
		guard isEnabled else { return }
		impactGenerator.prepare()
		selectionGenerator.prepare()
		notificationGenerator.prepare()
	}
}
