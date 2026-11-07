//
//  GuideCoordinatorTests.swift
//  flymoneyTests
//
//  Created by Javier Heisecke on 2026-11-07.
//

import Foundation
import Testing
@testable import flymoney

@Suite("Guide first use") @MainActor
struct GuideCoordinatorTests {
	@Test("Closing records the appearance and does not run the action")
	func cancellation() {
		let name = UUID().uuidString
		let defaults = UserDefaults(suiteName: name)!
		defer { defaults.removePersistentDomain(forName: name) }
		let coordinator = GuideCoordinator(defaults: defaults)
		var calls = 0
		coordinator.request(.statement) { calls += 1 }
		#expect(coordinator.presented == .statement)
		coordinator.appeared(.statement)
		coordinator.dismiss()
		coordinator.didDismiss()
		#expect(calls == 0)
		GuideCoordinator(defaults: defaults).request(.statement) { calls += 1 }
		#expect(calls == 1)
	}
	@Test("Continue executes once after dismissal")
	func continuation() {
		let name = UUID().uuidString
		let defaults = UserDefaults(suiteName: name)!
		defer { defaults.removePersistentDomain(forName: name) }
		let coordinator = GuideCoordinator(defaults: defaults)
		var calls = 0
		coordinator.request(.shareBudget) { calls += 1 }
		coordinator.appeared(.shareBudget)
		coordinator.proceed()
		coordinator.proceed()
		#expect(calls == 0)
		coordinator.didDismiss()
		coordinator.didDismiss()
		#expect(calls == 1)
	}
	@Test("A second request during dismissal cannot replace the pending action")
	func handoff() {
		let name = UUID().uuidString
		let defaults = UserDefaults(suiteName: name)!
		defer { defaults.removePersistentDomain(forName: name) }
		let coordinator = GuideCoordinator(defaults: defaults)
		var result = ""
		coordinator.request(.statement) { result = "first" }
		coordinator.proceed()
		coordinator.request(.template) { result = "second" }
		coordinator.didDismiss()
		#expect(result == "first")
		#expect(coordinator.presented == nil)
	}
	@Test("Legacy recurrence preferences suppress only the marking guide", arguments: [true, false])
	func legacy(flag: Bool) {
		let name = UUID().uuidString
		let defaults = UserDefaults(suiteName: name)!
		defer { defaults.removePersistentDomain(forName: name) }
		if flag { defaults.set(true, forKey: "hasSeenRecurringExpenseExplanation") }
		else { defaults.set(1, forKey: "recurringExpenseExplanationCount") }
		let coordinator = GuideCoordinator(defaults: defaults)
		#expect(coordinator.hasSeen(.recurringExpense))
		#expect(!coordinator.hasSeen(.recurringList))
	}
}
