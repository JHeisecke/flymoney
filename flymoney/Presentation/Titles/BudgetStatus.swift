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
	case over

	init(spent: Money, limit: Money) {
		guard limit.minorUnits > 0 else {
			self = .under
			return
		}
		if spent.minorUnits > limit.minorUnits {
			self = .over
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
		case .over: Theme.Colors.danger
		}
	}
}
