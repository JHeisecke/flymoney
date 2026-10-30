//
//  BudgetProfile.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-10-30.
//

import Foundation

enum BudgetProfile: String, CaseIterable, Identifiable, Sendable {
	case javier = "Javier"
	case iara = "Iara"
	var id: String { rawValue }
}
