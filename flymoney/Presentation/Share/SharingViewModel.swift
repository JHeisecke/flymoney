//
//  SharingViewModel.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import Foundation
import Observation

@MainActor
@Observable
final class SharingViewModel {
	enum Phase: Equatable {
		case idle
		case handshaking
		case sending(Double)
		case receiving(Double)
		case awaitingMerge(ImportedMonth)
		case saving
		case done
		case failed(String)
	}

	private(set) var phase: Phase = .idle
	private(set) var qrText: String?
	var resolutions: [UUID: MergeResolution] = [:]
	private(set) var fuzzyMatches: [UUID: [LocalMatch]] = [:]
	private(set) var combinedSummary: [MonthSummary] = []
	private(set) var localTitles: [ExpenseTitle] = []

	private let role: SharingRole
	private let exportMonth: any ExportMonthUseCase
	private let importShared: any ImportSharedMonthUseCase
	private let mergeTitles: any MergeTitlesUseCase
	private let fetchTitles: any FetchExpenseTitlesUseCase
	private let addExpense: any AddExpenseUseCase
	private let upsertTitle: any UpsertExpenseTitleUseCase
	private let sharingTransport: any SharingTransport
	let bleTransport: BLEQRSharingTransport?

	init(role: SharingRole,
		 exportMonth: any ExportMonthUseCase,
		 importShared: any ImportSharedMonthUseCase,
		 mergeTitles: any MergeTitlesUseCase,
		 fetchTitles: any FetchExpenseTitlesUseCase,
		 addExpense: any AddExpenseUseCase,
		 upsertTitle: any UpsertExpenseTitleUseCase,
		 transport: any SharingTransport,
		 bleTransport: BLEQRSharingTransport? = nil) {
		self.role = role
		self.exportMonth = exportMonth
		self.importShared = importShared
		self.mergeTitles = mergeTitles
		self.fetchTitles = fetchTitles
		self.addExpense = addExpense
		self.upsertTitle = upsertTitle
		self.sharingTransport = transport
		self.bleTransport = bleTransport
	}

	func start() async {
		switch role {
		case .send(let month):
			await startSend(month: month)
		case .receive:
			await startReceive()
		}
	}

	func cancel() {
		bleTransport?.cancel()
		phase = .idle
	}

	func provideScannedQR(_ text: String) {
		bleTransport?.provideScannedQR(text)
	}

	func setResolution(_ id: UUID, _ r: MergeResolution) async {
		resolutions[id] = r
		await recomputeSummary()
	}

	func saveToMyExpenses() async {
		guard case .awaitingMerge(let imported) = phase else { return }
		phase = .saving
		for title in imported.titles {
			let res = resolutions[title.id] ?? .keepSeparate
			switch res {
			case .mergeInto(let localID):
				guard let local = localTitles.first(where: { $0.id == localID }) else { continue }
				for expense in imported.expenses where expense.titleID == title.id {
					_ = try? await addExpense.execute(amount: expense.amount, titleName: local.name, date: expense.date)
				}
			case .keepSeparate:
				_ = try? await upsertTitle.execute(id: title.id, name: title.name, limit: title.limit, period: .calendarMonth)
				for expense in imported.expenses where expense.titleID == title.id {
					_ = try? await addExpense.execute(amount: expense.amount, titleName: title.name, date: expense.date)
				}
			}
		}
		phase = .done
	}

	private func startSend(month: CalendarMonth) async {
		do {
			let payload = try await exportMonth.execute(month)
			let stream = sharingTransport.send(payload)
			for await event in stream {
				switch event {
				case .handshaking:
					phase = .handshaking
					qrText = bleTransport?.qrText
				case .transferring(let p):
					phase = .sending(p)
				case .completed:
					phase = .done
					return
				case .received:
					break
				case .failed(let reason):
					phase = .failed(reason)
					return
				}
			}
		} catch {
			phase = .failed(error.localizedDescription)
		}
	}

	private func startReceive() async {
		let stream = sharingTransport.receive()
		for await event in stream {
			switch event {
			case .handshaking:
				phase = .handshaking
			case .transferring(let p):
				phase = .receiving(p)
			case .completed:
				break
			case .received(let payload):
				if let imported = try? importShared.execute(payload) {
					await loadLocalTitles()
					fuzzyMatches = MergeMatcher.findMatches(imported: imported.titles, local: localTitles)
					for (id, matches) in fuzzyMatches {
						if let strong = matches.first(where: { $0.isStrong }) {
							resolutions[id] = .mergeInto(localTitleID: strong.titleID)
						}
					}
					_ = try? remerge(imported)
					phase = .awaitingMerge(imported)
				} else {
					phase = .failed("Failed to decode share data")
				}
				return
			case .failed(let reason):
				phase = .failed(reason)
				return
			}
		}
	}

	private func loadLocalTitles() async {
		localTitles = (try? await fetchTitles.execute()) ?? []
	}

	private func recomputeSummary() async {
		guard case .awaitingMerge(let imported) = phase else { return }
		_ = try? remerge(imported)
	}

	private func remerge(_ imported: ImportedMonth) throws {
		combinedSummary = try mergeTitles.execute(local: localTitles, imported: imported, resolutions: resolutions)
	}
}
