//
//  MinesweeperSaveProbe.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-14.
//

import Foundation
@testable import flymoney

actor MinesweeperSaveProbe: AddExpenseUseCase {
    let wrapped: any AddExpenseUseCase
    private(set) var callCount = 0
    private var continuation: CheckedContinuation<Void, Never>?
    private var started: CheckedContinuation<Void, Never>?

    init(wrapped: any AddExpenseUseCase) { self.wrapped = wrapped }

    func execute(amount: Money, titleName: String, date: Date, detail: String?, isRecurring: Bool) async throws -> Expense {
        callCount += 1
        if callCount == 1 { throw ExpenseRepositoryError.notFound }
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            started?.resume()
            started = nil
        }
        return try await wrapped.execute(amount: amount, titleName: titleName, date: date,
            detail: detail, isRecurring: isRecurring)
    }

    func waitUntilSaving() async {
        if continuation != nil { return }
        await withCheckedContinuation { started = $0 }
    }

    func finishSaving() {
        continuation?.resume()
        continuation = nil
    }
}
