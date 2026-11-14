//
//  SharingRole.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import Foundation

enum SharingRole: Identifiable, Equatable {
	case send(month: CalendarMonth)
	case sendBudget(SavedBudget)
	case receive

	var id: String {
		switch self {
		case .send: return "send"
		case .sendBudget(let budget): return "budget-" + budget.id.uuidString
		case .receive: return "receive"
		}
	}
}
