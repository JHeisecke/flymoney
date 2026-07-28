//
//  TitleLimit.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-07-27.
//

import Foundation

/// An effective-dated limit change for a title. The effective limit for a month M
/// is the row with the greatest `effectiveMonthKey ≤ M.key`. A nil `limit` means
/// the limit was cleared from `effectiveMonthKey` on.
struct TitleLimit: Equatable, Sendable {
	let titleID: UUID
	let effectiveMonthKey: Int
	let limit: Money?
}
