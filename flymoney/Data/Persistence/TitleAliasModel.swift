//
//  TitleAliasModel.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-08-05.
//

import Foundation
import SwiftData

/// Remembers which `ExpenseTitle` a normalized statement-detail string maps
/// to, so re-importing the same merchant needs no further user action.
@Model
final class TitleAliasModel {
	@Attribute(.unique) var id: UUID
	@Attribute(.unique) var normalizedDetail: String
	var titleID: UUID
	var createdAt: Date

	init(id: UUID, normalizedDetail: String, titleID: UUID, createdAt: Date) {
		self.id = id
		self.normalizedDetail = normalizedDetail
		self.titleID = titleID
		self.createdAt = createdAt
	}
}
