//
//  BudgetTemplateRepository.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-10-30.
//

import Foundation

protocol BudgetTemplateRepository: Sendable {
	func load() throws -> BudgetTemplate
}
