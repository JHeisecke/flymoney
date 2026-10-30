//
//  SharingViewModelTests.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import Foundation
import Testing
import SwiftData
@testable import flymoney

final class FakeSharingTransport: SharingTransport, @unchecked Sendable {
	var nextEvents: [TransferEvent] = []
	var sentPayload: SharePayload?
	var receiveCalled = false
	var cancelCalled = false
	@MainActor func cancel() { cancelCalled = true }

	func send(_ payload: SharePayload) -> AsyncStream<TransferEvent> {
		sentPayload = payload
		return AsyncStream { cont in
			for event in nextEvents {
				cont.yield(event)
			}
			cont.finish()
		}
	}

	func receive() -> AsyncStream<TransferEvent> {
		receiveCalled = true
		return AsyncStream { cont in
			for event in nextEvents {
				cont.yield(event)
			}
			cont.finish()
		}
	}
}

@MainActor
@Suite("SharingViewModel", .tags(.viewModel))
struct SharingViewModelTests {

	private var utc: Calendar {
		var c = Calendar(identifier: .gregorian)
		c.timeZone = TimeZone(identifier: "UTC")!
		return c
	}

	private func makeVM(
		role: SharingRole,
		transport: FakeSharingTransport,
		expenses: InMemoryExpenseRepository = InMemoryExpenseRepository(),
		titles: InMemoryExpenseTitleRepository = InMemoryExpenseTitleRepository(),
		limits: InMemoryTitleLimitRepository = InMemoryTitleLimitRepository(),
        budgets: (any BudgetUseCases)? = nil
	) -> SharingViewModel {
		SharingViewModel(
			role: role,
			exportMonth: ExportMonthUseCaseImpl(expenses: expenses, titles: titles, limits: limits, currencyProvider: FixedCurrencyProvider("USD"), calendar: utc),
			importShared: ImportSharedMonthUseCaseImpl(),
			mergeTitles: MergeTitlesUseCaseImpl(),
			fetchTitles: FetchExpenseTitlesUseCaseImpl(titles: titles),
			addExpense: AddExpenseUseCaseImpl(expenses: expenses, titles: titles),
			upsertTitle: UpsertExpenseTitleUseCaseImpl(titles: titles),
			setTitleLimit: SetTitleLimitUseCaseImpl(limits: limits),
			fetchLimits: FetchEffectiveLimitsUseCaseImpl(limits: limits),
			transport: transport, budgetUseCases: budgets)
	}

	@Test("Unexpected stream completion fails instead of leaving a spinner", arguments: [true, false])
	func unexpectedCompletion(sending: Bool) async {
		let transport = FakeSharingTransport()
		let vm = makeVM(role: sending ? .send(month: CalendarMonth(year: 2026, month: 11)) : .receive, transport: transport)
		await vm.start()
		if case .failed = vm.phase {} else { Issue.record("Expected explicit failure") }
	}

	@Test("sender happy path event trail")
	func senderHappyPath() async {
		let transport = FakeSharingTransport()
		transport.nextEvents = [
			.handshaking,
			.transferring(progress: 0.5),
			.completed,
		]
		let vm = makeVM(role: .send(month: CalendarMonth(year: 2025, month: 6)), transport: transport)

		await vm.start()
		#expect(vm.phase == .done)
	}

	@Test("sender failure event trail")
	func senderFailure() async {
		let transport = FakeSharingTransport()
		transport.nextEvents = [
			.handshaking,
			.failed(reason: "test error"),
		]
		let vm = makeVM(role: .send(month: CalendarMonth(year: 2025, month: 6)), transport: transport)

		await vm.start()
		if case .failed(let reason) = vm.phase {
			#expect(reason == "test error")
		} else {
			#expect(Bool(false))
		}
	}

	@Test("receiver happy path with received payload")
	func receiverHappyPath() async {
		let transport = FakeSharingTransport()
		let payload = SharePayload(
			version: 1,
			currencyCode: "USD",
			month: CalendarMonth(year: 2025, month: 6),
			titles: [SharePayload.TitleDTO(id: UUID(), name: "Coffee", limitMinorUnits: nil)],
			expenses: [SharePayload.ExpenseDTO(id: UUID(), titleID: UUID(), amountMinorUnits: 100, date: Date(timeIntervalSince1970: 1748736000))]
		)
		transport.nextEvents = [
			.handshaking,
			.transferring(progress: 1.0),
			.received(payload),
		]
		let vm = makeVM(role: .receive, transport: transport)

		await vm.start()
		if case .awaitingMerge = vm.phase {
			#expect(true)
		} else {
			#expect(Bool(false))
		}
	}

	@Test("cancel resets phase to idle")
	func cancelResets() async {
		let vm = makeVM(role: .receive, transport: FakeSharingTransport())
		vm.cancel()
		#expect(vm.phase == .idle)
	}


    @Test("Saving a reviewed share uses the atomic budget writer")
    func saveKeepSeparateWritesLimitRow() async throws {
        let transport = FakeSharingTransport()
        let container = try SwiftDataStack.makeInMemoryContainer()
        let repo = SwiftDataBudgetRepository(modelContainer: container, currencyCode: "USD")
        let budgets = BudgetUseCasesImpl(repository: repo, templates: BundledBudgetTemplateRepository())
        let month = CalendarMonth(year: 2025, month: 6)
        let id = UUID()
        let payload = SharePayload(version: 1, currencyCode: "USD", month: month,
            titles: [.init(id: id, name: "Coffee", limitMinorUnits: 5000)], expenses: [])
        transport.nextEvents = [.received(payload)]
        let vm = makeVM(role: .receive, transport: transport, budgets: budgets)
        await vm.start()
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<ExpenseTitleModel>()) == 0)
        await vm.saveToMyExpenses()
        #expect(vm.phase == .done)
        let stored = try ModelContext(container).fetch(FetchDescriptor<TitleLimitModel>())
        #expect(stored.first?.limitMinorUnits == 5000)
        #expect(stored.first?.effectiveMonthKey == month.key)
    }

	@Test("export carries the shared month's effective limit")
	func exportCarriesSharedMonthLimit() async throws {
		let transport = FakeSharingTransport()
		let expenses = InMemoryExpenseRepository()
		let titles = InMemoryExpenseTitleRepository()
		let limits = InMemoryTitleLimitRepository()
		let month = CalendarMonth(year: 2025, month: 6)
		let title = ExpenseTitle(id: UUID(), name: "Coffee")
		try await titles.upsert(title)
		try await limits.setLimit(Money(minorUnits: 50000, currencyCode: "USD"), forTitleID: title.id, effectiveMonthKey: CalendarMonth(year: 2025, month: 4).key)
		try await limits.setLimit(Money(minorUnits: 30000, currencyCode: "USD"), forTitleID: title.id, effectiveMonthKey: CalendarMonth(year: 2025, month: 7).key)
		try await expenses.add(Expense(amount: Money(minorUnits: 100, currencyCode: "USD"), titleID: title.id, date: Date(timeIntervalSince1970: 1748736000)))
		transport.nextEvents = [.completed]

		let vm = makeVM(role: .send(month: month), transport: transport, expenses: expenses, titles: titles, limits: limits)
		await vm.start()

		let payload = try #require(transport.sentPayload)
		let dto = try #require(payload.titles.first)
		// June resolves to the April change; the July change must not leak in.
		#expect(dto.limitMinorUnits == 50000)
	}
}
