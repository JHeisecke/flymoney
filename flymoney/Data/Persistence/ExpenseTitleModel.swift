//
//  ExpenseTitleModel.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import Foundation
import SwiftData

@Model
final class ExpenseTitleModel {
	@Attribute(.unique) var id: UUID
	var name: String
	var limitMinorUnits: Int?
	var currencyCode: String
	var createdAt: Date
	var lastUsedAt: Date?

	init(id: UUID, name: String, limitMinorUnits: Int?, currencyCode: String, createdAt: Date, lastUsedAt: Date? = nil) {
		self.id = id
		self.name = name
		self.limitMinorUnits = limitMinorUnits
		self.currencyCode = currencyCode
		self.createdAt = createdAt
		self.lastUsedAt = lastUsedAt
	}
}
