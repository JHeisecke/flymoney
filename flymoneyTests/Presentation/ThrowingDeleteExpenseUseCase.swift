//
//  ThrowingDeleteExpenseUseCase.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import Foundation
@testable import flymoney

struct ThrowingDeleteExpenseUseCase: DeleteExpenseUseCase {
	func execute(id: UUID) async throws {
		throw DeleteError.generic
	}

	enum DeleteError: Error { case generic }
}
