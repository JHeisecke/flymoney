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

	private func makeVM(role: SharingRole, transport: FakeSharingTransport) -> SharingViewModel {
		let expenses = InMemoryExpenseRepository()
		let titles = InMemoryExpenseTitleRepository()
		return SharingViewModel(
			role: role,
			exportMonth: ExportMonthUseCaseImpl(expenses: expenses, titles: titles, currencyProvider: FixedCurrencyProvider("USD")),
			importShared: ImportSharedMonthUseCaseImpl(),
			mergeTitles: MergeTitlesUseCaseImpl(),
			fetchTitles: FetchExpenseTitlesUseCaseImpl(titles: titles),
			addExpense: AddExpenseUseCaseImpl(expenses: expenses, titles: titles),
			upsertTitle: UpsertExpenseTitleUseCaseImpl(titles: titles),
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
}
