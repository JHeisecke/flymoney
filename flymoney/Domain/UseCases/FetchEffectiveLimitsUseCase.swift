//
//  FetchEffectiveLimitsUseCase.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-07-27.
//

import Foundation

protocol FetchEffectiveLimitsUseCase: Sendable {
	func execute(_ month: CalendarMonth) async throws -> [UUID: Money]
}

struct FetchEffectiveLimitsUseCaseImpl: FetchEffectiveLimitsUseCase {
	let limits: TitleLimitRepository

	func execute(_ month: CalendarMonth) async throws -> [UUID: Money] {
		try await limits.effectiveLimits(monthKey: month.key)
	}
}
