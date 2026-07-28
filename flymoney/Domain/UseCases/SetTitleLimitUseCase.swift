//
//  SetTitleLimitUseCase.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-07-27.
//

import Foundation

protocol SetTitleLimitUseCase: Sendable {
	func execute(titleID: UUID, limit: Money?, effectiveMonth: CalendarMonth) async throws
}

struct SetTitleLimitUseCaseImpl: SetTitleLimitUseCase {
	let limits: TitleLimitRepository

	func execute(titleID: UUID, limit: Money?, effectiveMonth: CalendarMonth) async throws {
		try await limits.setLimit(limit, forTitleID: titleID, effectiveMonthKey: effectiveMonth.key)
	}
}
