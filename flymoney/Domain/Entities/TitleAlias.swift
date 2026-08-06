//
//  TitleAlias.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-08-05.
//

import Foundation

struct TitleAlias: Identifiable, Equatable, Sendable {
	let id: UUID
	let normalizedDetail: String
	let titleID: UUID
	let createdAt: Date

	init(id: UUID = UUID(), normalizedDetail: String, titleID: UUID, createdAt: Date = .now) {
		self.id = id
		self.normalizedDetail = normalizedDetail
		self.titleID = titleID
		self.createdAt = createdAt
	}
}
