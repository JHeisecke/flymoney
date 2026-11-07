//
//  GuideCoordinator.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-07.
//

import SwiftUI

@MainActor @Observable
final class GuideCoordinator {
	private let defaults: UserDefaults
	var presented: Guide?
	private var continuation: (() -> Void)?
	private var shouldContinue = false
	init(defaults: UserDefaults = .standard) {
		self.defaults = defaults
	}

	func request(_ guide: Guide, action: @escaping () -> Void) {
		guard presented == nil, continuation == nil else { return }
		if hasSeen(guide) {
			action()
			return
		}
		continuation = action
		shouldContinue = false
		presented = guide
	}

	func hasSeen(_ guide: Guide) -> Bool {
		defaults.bool(forKey: "guide.seen.\(guide.rawValue)") ||
			(guide == .recurringExpense && (
				defaults.bool(forKey: "hasSeenRecurringExpenseExplanation") ||
				defaults.integer(forKey: "recurringExpenseExplanationCount") > 0
			))
	}
	func appeared(_ guide: Guide) {
		defaults.set(true, forKey: "guide.seen.\(guide.rawValue)")
	}

	func proceed() {
		guard presented != nil, !shouldContinue else { return }
		shouldContinue = true
		presented = nil
	}

	func dismiss() {
		presented = nil
	}


	func didDismiss() {
		let action = shouldContinue ? continuation : nil
		continuation = nil
		shouldContinue = false
		action?()
	}
}
