//
//  BundledBudgetTemplateRepository.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-10-30.
//

import Foundation

struct BundledBudgetTemplateRepository: BudgetTemplateRepository {
	func load() throws -> BudgetTemplate {
		guard let url = Bundle.main.url(forResource: "matrimonial-november-2026", withExtension: "json") else {
			throw BudgetError.invalidPayload
		}
		let template = try JSONDecoder().decode(BudgetTemplate.self, from: Data(contentsOf: url))
		guard template.version == 1, template.currencyCode == "PYG" else { throw BudgetError.invalidPayload }
		return template
	}
}
