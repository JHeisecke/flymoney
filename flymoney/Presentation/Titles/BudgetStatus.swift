//
//  BudgetStatus.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-30.
//

import SwiftUI

enum BudgetStatus: Equatable {
	case under
	case near
	case exhausted
	case over

	init(spent: Money, limit: Money) {
		guard limit.minorUnits > 0 else {
			self = .under
			return
		}
		if spent.minorUnits > limit.minorUnits {
			self = .over
		} else if spent.minorUnits == limit.minorUnits {
			self = .exhausted
		} else if Double(spent.minorUnits) / Double(limit.minorUnits) >= 0.9 {
			self = .near
		} else {
			self = .under
		}
	}

	var color: Color {
		switch self {
		case .under: Theme.Colors.success
		case .near: Theme.Colors.warning
		case .exhausted, .over: Theme.Colors.danger
		}
	}

	func caption(for remaining: Money) -> String {
		switch self {
		case .under, .near:
			return String(localized: "Left \(remaining.formatted())")
		case .exhausted:
			return String(localized: "No funds left · \(remaining.formatted())")
		case .over:
			let excess = Money(minorUnits: abs(remaining.minorUnits), currencyCode: remaining.currencyCode)
			return String(localized: "Over by \(excess.formatted())")
		}
	}
}
