//
//  BudgetError.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-10-30.
//

import Foundation

enum BudgetError: Error, LocalizedError {
	case invalidPayload, currency, staleReview, ambiguousCategory, changedRevision, missingCategory
	var errorDescription: String? {
		switch self {
		case .invalidPayload: String(localized: "This budget contains invalid or unsupported data.")
		case .currency: String(localized: "This budget uses a different currency. No changes were saved.")
		case .staleReview: String(localized: "Your data changed. Refresh the review before saving.")
		case .ambiguousCategory: String(localized: "Choose a different category for each budget item.")
		case .changedRevision: String(localized: "This revision was already received with different content.")
		case .missingCategory: String(localized: "A linked category was deleted. Choose its replacement.")
		}
	}
}
