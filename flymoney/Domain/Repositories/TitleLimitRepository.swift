//
//  TitleLimitRepository.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-07-27.
//

import Foundation

protocol TitleLimitRepository: Sendable {
	/// Effective limit for one title in a month (latest row ≤ monthKey; nil if none or cleared).
	func limit(forTitleID id: UUID, monthKey: Int) async throws -> Money?
	/// Effective limit for every title in a month — one query for the Titles list.
	func effectiveLimits(monthKey: Int) async throws -> [UUID: Money]
	/// Upsert the row at `monthKey` (nil == cleared / no-limit change).
	func setLimit(_ limit: Money?, forTitleID id: UUID, effectiveMonthKey monthKey: Int) async throws
	/// All rows for a title, ascending — for the editor / debugging.
	func limits(forTitleID id: UUID) async throws -> [TitleLimit]
	/// Cascade on title delete.
	func deleteAll(forTitleID id: UUID) async throws
}
