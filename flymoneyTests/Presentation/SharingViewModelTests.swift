//
//  SharingViewModelTests.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import Foundation
import Testing
@testable import flymoney

final class FakeSharingTransport: SharingTransport, @unchecked Sendable {
	var nextEvents: [TransferEvent] = []
	var sentPayload: SharePayload?
	var receiveCalled = false

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
		limits: InMemoryTitleLimitRepository = InMemoryTitleLimitRepository()
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
			transport: transport)
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

	@Test("saveToMyExpenses keepSeparate writes the shared month's limit row")
	func saveKeepSeparateWritesLimitRow() async throws {
		let transport = FakeSharingTransport()
		let expenses = InMemoryExpenseRepository()
		let titles = InMemoryExpenseTitleRepository()
		let limits = InMemoryTitleLimitRepository()
		let month = CalendarMonth(year: 2025, month: 6)
		let dtoTitleID = UUID()
		let payload = SharePayload(
			version: 1,
			currencyCode: "USD",
			month: month,
			titles: [SharePayload.TitleDTO(id: dtoTitleID, name: "Coffee", limitMinorUnits: 5000)],
			expenses: [SharePayload.ExpenseDTO(id: UUID(), titleID: dtoTitleID, amountMinorUnits: 100, date: Date(timeIntervalSince1970: 1748736000))]
		)
		transport.nextEvents = [.received(payload)]
		let vm = makeVM(role: .receive, transport: transport, expenses: expenses, titles: titles, limits: limits)

		await vm.start()
		guard case .awaitingMerge = vm.phase else {
			#expect(Bool(false))
			return
		}
		await vm.saveToMyExpenses()

		#expect(vm.phase == .done)
		let savedTitle = try await titles.title(named: "Coffee")
		let savedTitleID = try #require(savedTitle?.id)
		let resolved = try await limits.limit(forTitleID: savedTitleID, monthKey: month.key)
		#expect(resolved?.minorUnits == 5000)
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
