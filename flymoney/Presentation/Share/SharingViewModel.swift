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
	private var localLimits: [UUID: Money] = [:]

	var includesExpenses = true
	private(set) var exportPreview: SharePayload?
	private(set) var previewError: String?
	private var previewID: UUID?
	var shareMonth: CalendarMonth? {
		if case .send(let month) = role { return month }
		return nil
	}
	func prepareExportPreview() async {
		guard let month = shareMonth else { return }
		let id = UUID()
		previewID = id
		exportPreview = nil
		previewError = nil
		do {
			let payload: SharePayload
			if let budgetUseCases {
				payload = try await budgetUseCases.preview(
					month: month, includesExpenses: includesExpenses)
			} else {
				payload = try await exportMonth.execute(month)
			}
			guard !Task.isCancelled, previewID == id else { return }
			exportPreview = payload
		} catch { if !Task.isCancelled, previewID == id { previewError = error.localizedDescription } }
	}
	private(set) var budgetReviewModel: BudgetReviewViewModel?
	private let budgetUseCases: (any BudgetUseCases)?
	private var runID: UUID?

	private let role: SharingRole
	private let exportMonth: any ExportMonthUseCase
	private let importShared: any ImportSharedMonthUseCase
	private let mergeTitles: any MergeTitlesUseCase
	private let fetchTitles: any FetchExpenseTitlesUseCase
	private let addExpense: any AddExpenseUseCase
	private let upsertTitle: any UpsertExpenseTitleUseCase
	private let setTitleLimit: any SetTitleLimitUseCase
	private let fetchLimits: any FetchEffectiveLimitsUseCase
	private let sharingTransport: any SharingTransport

	init(
		role: SharingRole,
		exportMonth: any ExportMonthUseCase,
		importShared: any ImportSharedMonthUseCase,
		mergeTitles: any MergeTitlesUseCase,
		fetchTitles: any FetchExpenseTitlesUseCase,
		addExpense: any AddExpenseUseCase,
		upsertTitle: any UpsertExpenseTitleUseCase,
		setTitleLimit: any SetTitleLimitUseCase,
		fetchLimits: any FetchEffectiveLimitsUseCase,
		transport: any SharingTransport, budgetUseCases: (any BudgetUseCases)? = nil
	) {
		self.budgetUseCases = budgetUseCases
		self.role = role
		self.exportMonth = exportMonth
		self.importShared = importShared
		self.mergeTitles = mergeTitles
		self.fetchTitles = fetchTitles
		self.addExpense = addExpense
		self.upsertTitle = upsertTitle
		self.setTitleLimit = setTitleLimit
		self.fetchLimits = fetchLimits
		self.sharingTransport = transport
	}

	func start() async {
		guard runID == nil, !Task.isCancelled else { return }
		let id = UUID()
		runID = id
		phase = .handshaking
		defer { if runID == id { runID = nil } }
		switch role {
		case .send(let month):
			await startSend(month: month, id: id)
		case .receive:
			await startReceive(id: id)
		}
	}

	func cancel() {
		runID = nil
		qrText = nil
		sharingTransport.cancel()
		phase = .idle
	}

	func provideScannedQR(_ text: String) {
		sharingTransport.provideScannedQR(text)
	}

	func setResolution(_ id: UUID, _ r: MergeResolution) async {
		resolutions[id] = r
		await recomputeSummary()
	}

	func saveToMyExpenses() async {
		guard let budgetReviewModel else {
			phase = .failed(String(localized: "This budget contains invalid or unsupported data."))
			return
		}
		await budgetReviewModel.save()
		if budgetReviewModel.isSaved { phase = .done }
	}

	private func startSend(month: CalendarMonth, id: UUID) async {
		do {
			let payload: SharePayload
			if let budgetUseCases {
				payload = try await budgetUseCases.export(
					month: month, includesExpenses: includesExpenses)
			} else {
				payload = try await exportMonth.execute(month)
			}
			guard runID == id, !Task.isCancelled else { return }
			let stream = sharingTransport.send(payload)
			for await event in stream {
				guard runID == id, !Task.isCancelled else { return }
				switch event {
				case .handshaking:
					phase = .handshaking
					qrText = sharingTransport.qrText
				case .transferring(let p):
					phase = .sending(p)
				case .completed:
					qrText = nil
					phase = .done
					return
				case .received:
					break
				case .failed(let reason):
					qrText = nil
					phase = .failed(reason)
					return
				}
			}
			if runID == id {
				phase = .failed(
					String(localized: "Reception could not be confirmed. Reconnect and try again."))
			}
		} catch {
			guard runID == id else { return }
			phase = .failed(error.localizedDescription)
		}
	}

	private func startReceive(id: UUID) async {
		let stream = sharingTransport.receive()
		for await event in stream {
			guard runID == id, !Task.isCancelled else { return }
			switch event {
			case .handshaking:
				phase = .handshaking
			case .transferring(let p):
				phase = .receiving(p)
			case .completed:
				break
			case .received(let payload):
				if let budgetUseCases {
					do {
						let review = try await budgetUseCases.prepareReceived(payload)
						guard runID == id, !Task.isCancelled else { return }
						budgetReviewModel = BudgetReviewViewModel(
							review: review, useCases: budgetUseCases)
						phase = .awaitingMerge(try importShared.execute(payload))
					} catch { phase = .failed(error.localizedDescription) }
					return
				}
				if let imported = try? importShared.execute(payload) {
					await loadLocalTitles()
					await loadLocalLimits(for: imported.month)
					guard runID == id, !Task.isCancelled else { return }
					fuzzyMatches = MergeMatcher.findMatches(
						imported: imported.titles, local: localTitles)
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
				qrText = nil
				phase = .failed(reason)
				return
			}
		}
		if runID == id {
			phase = .failed(String(localized: "Reception could not be confirmed. Reconnect and try again."))
		}
	}

	private func loadLocalTitles() async {
		localTitles = (try? await fetchTitles.execute()) ?? []
	}

	private func loadLocalLimits(for month: CalendarMonth) async {
		localLimits = (try? await fetchLimits.execute(month)) ?? [:]
	}

	private func recomputeSummary() async {
		guard case .awaitingMerge(let imported) = phase else { return }
		_ = try? remerge(imported)
	}

	private func remerge(_ imported: ImportedMonth) throws {
		combinedSummary = try mergeTitles.execute(
			local: localTitles, localLimits: localLimits, imported: imported, resolutions: resolutions)
	}
}
