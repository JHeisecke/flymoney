//
//  TitleLimitModel.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-07-27.
//

import Foundation
import SwiftData

/// One row per (title, effectiveMonth). `limitMinorUnits == nil` is a real
/// effective-dated change meaning "no limit from this month on".
@Model
final class TitleLimitModel {
	@Attribute(.unique) var id: UUID
	var titleID: UUID
	var effectiveMonthKey: Int
	var limitMinorUnits: Int?
	var currencyCode: String

	init(id: UUID = UUID(), titleID: UUID, effectiveMonthKey: Int, limitMinorUnits: Int?, currencyCode: String) {
		self.id = id
		self.titleID = titleID
		self.effectiveMonthKey = effectiveMonthKey
		self.limitMinorUnits = limitMinorUnits
		self.currencyCode = currencyCode
	}
}
