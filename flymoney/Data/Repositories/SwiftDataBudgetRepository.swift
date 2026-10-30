//
//  SwiftDataBudgetRepository.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-10-30.
//

import CryptoKit
import Foundation
import SwiftData

/// All mutations for a budget share one isolated context and one durable save.
actor SwiftDataBudgetRepository: BudgetRepository, ModelActor {
	nonisolated let modelContainer: ModelContainer
	nonisolated let modelExecutor: any ModelExecutor
	private let currencyCode: String
	private let calendar: Calendar
	init(modelContainer: ModelContainer, currencyCode: String, calendar: Calendar = .current) {
		self.modelContainer = modelContainer
		self.modelExecutor = DefaultSerialModelExecutor(modelContext: ModelContext(modelContainer))
		self.currencyCode = currencyCode
		self.calendar = calendar
	}
	private func context() -> ModelContext {
		let context = ModelContext(modelContainer)
		context.autosaveEnabled = false
		return context
	}
	func prepare(_ payload: SharePayload) throws -> BudgetReview { try prepare(payload, context: context()) }
	private func prepare(_ payload: SharePayload, context: ModelContext) throws -> BudgetReview {
		try BudgetPayloadValidation.validate(payload)
		guard try SharePayloadCodec.encode(payload).count <= ChunkedTransfer.maximumPayloadSize else {
			throw BudgetError.invalidPayload
		}
		guard payload.currencyCode == currencyCode else { throw BudgetError.currency }
		let fingerprint = try hash(payload)
		let receiptKey = receiptKey(payload, fingerprint: fingerprint)
		let receipts = try context.fetch(FetchDescriptor<BudgetImportReceiptModel>())
		if let receipt = receipts.first(where: { $0.key == receiptKey }), receipt.fingerprint != fingerprint {
			throw BudgetError.changedRevision
		}
		let titles = try context.fetch(FetchDescriptor<ExpenseTitleModel>())
		let limits = try effectiveLimits(context, month: payload.month)
		let allLinks = try context.fetch(FetchDescriptor<BudgetCategoryLinkModel>())
		let links = allLinks.filter { $0.budgetID == payload.budgetID }
		var rows: [BudgetReviewRow] = []
		for remote in payload.titles {
			let linked = links.first { $0.conceptID == remote.id }
			let exact = titles.filter { normalize($0.name) == normalize(remote.name) }
			let existing =
				linked.flatMap { link in titles.first { $0.id == link.localTitleID } }
				?? (linked == nil && exact.count == 1 ? exact.first : nil)
			if let existing, existing.currencyCode != currencyCode { throw BudgetError.currency }
			let newID = titles.contains(where: { $0.id == remote.id }) ? UUID() : remote.id
			rows.append(
				BudgetReviewRow(
					id: remote.id, name: remote.name,
					incomingLimit: remote.limitMinorUnits.map {
						Money(minorUnits: $0, currencyCode: payload.currencyCode)
					},
					localTitleID: existing?.id, newTitleID: newID,
					useIncomingLimit: existing == nil,
					localLimits: limits,
					requiresSelection: (linked != nil && existing == nil)
						|| (linked == nil && exact.count > 1)))
		}
		let expenses = try context.fetch(FetchDescriptor<ExpenseModel>())
		var processed = Set(expenses.map(\.id))
		for receipt in receipts {
			processed.formUnion(try JSONDecoder().decode([UUID].self, from: receipt.processedExpenseIDs))
		}
		var conflicts: Set<UUID> = []
		for remote in payload.expenses {
			if let local = expenses.first(where: { $0.id == remote.id }) {
				let target = rows.first { $0.id == remote.titleID }
				if local.amountMinorUnits != remote.amountMinorUnits || local.date != remote.date
					|| local.currencyCode != payload.currencyCode
					|| local.titleID != (target?.localTitleID ?? target?.newTitleID)
				{
					conflicts.insert(remote.id)
				}
			}
		}
		return BudgetReview(
			payload: payload, fingerprint: fingerprint, snapshot: try snapshot(context),
			knownPlan: try context.fetch(FetchDescriptor<BudgetPlanModel>()).contains {
				$0.id == payload.budgetID
			},
			localCategories: titles.map { $0.toEntity() }.sorted {
				$0.name.localizedStandardCompare($1.name) == .orderedAscending
			},
			rows: rows, existingExpenseIDs: processed, conflictingExpenseIDs: conflicts)
	}
	func commit(_ review: BudgetReview) throws { try commit(review, beforeSave: nil) }
	/// Synchronous fault injection proves rollback without allowing actor reentrancy.
	func commit(_ review: BudgetReview, beforeSave: (@Sendable () throws -> Void)?) throws {
		let context = context()
		do {
			try Task.checkCancellation()
			let refreshed = try prepare(review.payload, context: context)
			guard refreshed.snapshot == review.snapshot, refreshed.fingerprint == review.fingerprint else {
				throw BudgetError.staleReview
			}
			guard review.rows.count == review.payload.titles.count,
				Set(review.rows.map(\.id)) == Set(review.payload.titles.map(\.id)),
				!review.rows.contains(where: \.requiresSelection)
			else { throw BudgetError.ambiguousCategory }
			let targets = review.rows.map { $0.localTitleID ?? $0.newTitleID }
			guard Set(targets).count == targets.count else { throw BudgetError.ambiguousCategory }
			let localTitles = try context.fetch(FetchDescriptor<ExpenseTitleModel>())
			let limits = try context.fetch(FetchDescriptor<TitleLimitModel>())
			let previousLinks = try context.fetch(FetchDescriptor<BudgetCategoryLinkModel>())
			var mapping: [UUID: UUID] = [:]
			for row in review.rows {
				guard let incoming = review.payload.titles.first(where: { $0.id == row.id }),
					incoming.name == row.name,
					incoming.limitMinorUnits == row.incomingLimit?.minorUnits
				else { throw BudgetError.invalidPayload }
				let localID = row.localTitleID ?? row.newTitleID
				if let id = row.localTitleID {
					guard let title = localTitles.first(where: { $0.id == id }) else {
						throw BudgetError.staleReview
					}
					guard title.currencyCode == currencyCode else { throw BudgetError.currency }
				} else {
					guard !localTitles.contains(where: { $0.id == localID }) else {
						throw BudgetError.staleReview
					}
					context.insert(
						ExpenseTitleModel(
							id: localID, name: row.name, currencyCode: currencyCode,
							createdAt: .now))
				}
				if let budgetID = review.payload.budgetID {
					guard
						!previousLinks.contains(where: {
							$0.budgetID == budgetID && $0.localTitleID == localID
								&& $0.conceptID != row.id
						})
					else { throw BudgetError.ambiguousCategory }
				}
				mapping[row.id] = localID
				if row.useIncomingLimit || row.localTitleID == nil {
					if let existing = limits.first(where: {
						$0.titleID == localID
							&& $0.effectiveMonthKey == review.payload.month.key
					}) {
						existing.limitMinorUnits = incoming.limitMinorUnits
						existing.currencyCode = currencyCode
					} else if incoming.limitMinorUnits != nil || row.localTitleID != nil {
						context.insert(
							TitleLimitModel(
								titleID: localID,
								effectiveMonthKey: review.payload.month.key,
								limitMinorUnits: incoming.limitMinorUnits,
								currencyCode: currencyCode))
					}
				}
			}
			if let budgetID = review.payload.budgetID {
				try ensurePlan(budgetID, month: review.payload.month, context: context)
				let links = try context.fetch(FetchDescriptor<BudgetCategoryLinkModel>())
				for (concept, local) in mapping {
					if let link = links.first(where: {
						$0.budgetID == budgetID && $0.conceptID == concept
					}) {
						link.localTitleID = local
					} else {
						context.insert(
							BudgetCategoryLinkModel(
								budgetID: budgetID, conceptID: concept,
								localTitleID: local))
					}
				}
			}
			for expense in review.payload.expenses where !refreshed.existingExpenseIDs.contains(expense.id)
			{
				guard let localID = mapping[expense.titleID] else { throw BudgetError.invalidPayload }
				context.insert(
					ExpenseModel(
						id: expense.id, amountMinorUnits: expense.amountMinorUnits,
						currencyCode: currencyCode, titleID: localID, date: expense.date))
			}
			let key = receiptKey(review.payload, fingerprint: review.fingerprint)
			let ids = try JSONEncoder().encode(review.payload.expenses.map(\.id))
			let decisions = try JSONEncoder().encode(
				BudgetReceiptRecord(
					version: 1, month: review.payload.month,
					includesExpenses: review.payload.includesExpenses ?? true,
					choices: review.rows.map {
						.init(
							conceptID: $0.id,
							localTitleID: $0.localTitleID ?? $0.newTitleID,
							useIncomingLimit: $0.useIncomingLimit)
					}))
			if let receipt = try context.fetch(FetchDescriptor<BudgetImportReceiptModel>()).first(where: {
				$0.key == key
			}) {
				receipt.decisions = decisions
			} else {
				context.insert(
					BudgetImportReceiptModel(
						key: key, fingerprint: review.fingerprint, processedExpenseIDs: ids,
						decisions: decisions))
			}
			try validateTotals(context)
			try beforeSave?()
			try Task.checkCancellation()
			try context.save()
		} catch {
			context.rollback()
			throw error
		}
	}
	func preview(month: CalendarMonth, includesExpenses: Bool) throws -> SharePayload {
		try export(month: month, includesExpenses: includesExpenses, persistIdentity: false)
	}
	func export(month: CalendarMonth, includesExpenses: Bool) throws -> SharePayload {
		try export(month: month, includesExpenses: includesExpenses, persistIdentity: true)
	}
	private func export(month: CalendarMonth, includesExpenses: Bool, persistIdentity: Bool) throws -> SharePayload
	{
		let context = context()
		do {
			guard (1900...9999).contains(month.year), (1...12).contains(month.month) else {
				throw BudgetError.invalidPayload
			}
			let selection = try context.fetch(FetchDescriptor<BudgetSharingSelectionModel>()).first
			let budgetID = selection?.budgetID ?? UUID()
			try ensurePlan(budgetID, month: month, context: context)
			let titles = try context.fetch(FetchDescriptor<ExpenseTitleModel>())
			let limits = try effectiveLimits(context, month: month)
			var expenses: [ExpenseModel] = []
			if includesExpenses {
				let interval = month.interval(using: calendar)
				let start = interval.start
				let end = interval.end
				expenses = try context.fetch(
					FetchDescriptor<ExpenseModel>(
						predicate: #Predicate { $0.date >= start && $0.date < end }))
			}
			let ids = Set(limits.keys).union(expenses.map(\.titleID))
			guard ids.isSubset(of: Set(titles.map(\.id))),
				expenses.allSatisfy({ $0.currencyCode == currencyCode })
			else { throw BudgetError.currency }
			let relevant = titles.filter { ids.contains($0.id) }
			guard relevant.allSatisfy({ $0.currencyCode == currencyCode }) else {
				throw BudgetError.currency
			}
			let links = try context.fetch(FetchDescriptor<BudgetCategoryLinkModel>()).filter {
				$0.budgetID == budgetID
			}
			var mapping: [UUID: UUID] = [:]
			var used: Set<UUID> = []
			for title in relevant {
				let matches = links.filter { $0.localTitleID == title.id }
				guard matches.count <= 1 else { throw BudgetError.ambiguousCategory }
				let concept = matches.first?.conceptID ?? title.id
				guard used.insert(concept).inserted else { throw BudgetError.ambiguousCategory }
				mapping[title.id] = concept
				if matches.isEmpty {
					context.insert(
						BudgetCategoryLinkModel(
							budgetID: budgetID, conceptID: concept, localTitleID: title.id))
				}
			}
			let payload = SharePayload(
				version: 2, currencyCode: currencyCode, month: month,
				titles: try relevant.map { title in
					guard let concept = mapping[title.id] else { throw BudgetError.invalidPayload }
					return .init(
						id: concept, name: title.name,
						limitMinorUnits: limits[title.id]?.minorUnits)
				},
				expenses: try expenses.map { expense in
					guard let concept = mapping[expense.titleID] else {
						throw BudgetError.invalidPayload
					}
					return .init(
						id: expense.id, titleID: concept,
						amountMinorUnits: expense.amountMinorUnits, date: expense.date)
				}, budgetID: budgetID, revisionID: UUID(), includesExpenses: includesExpenses,
				timeZoneIdentifier: calendar.timeZone.identifier)
			try BudgetPayloadValidation.validate(payload)
			guard try SharePayloadCodec.encode(payload).count <= ChunkedTransfer.maximumPayloadSize else {
				throw BLETransferError.size
			}
			try Task.checkCancellation()
			if persistIdentity { try context.save() } else { context.rollback() }
			return payload
		} catch {
			context.rollback()
			throw error
		}
	}
	private func ensurePlan(_ id: UUID, month: CalendarMonth, context: ModelContext) throws {
		if let plan = try context.fetch(FetchDescriptor<BudgetPlanModel>()).first(where: { $0.id == id }) {
			guard plan.currencyCode == currencyCode else { throw BudgetError.currency }
		} else {
			context.insert(BudgetPlanModel(id: id, currencyCode: currencyCode, initialMonthKey: month.key))
		}
		if let selection = try context.fetch(FetchDescriptor<BudgetSharingSelectionModel>()).first {
			selection.budgetID = id
		} else {
			context.insert(BudgetSharingSelectionModel(budgetID: id))
		}
	}
	private func effectiveLimits(_ context: ModelContext, month: CalendarMonth) throws -> [UUID: Money] {
		let rows = try context.fetch(
			FetchDescriptor<TitleLimitModel>(sortBy: [SortDescriptor(\.effectiveMonthKey, order: .reverse)])
		)
		var seen: Set<UUID> = []
		var values: [UUID: Money] = [:]
		for row in rows where row.effectiveMonthKey <= month.key && seen.insert(row.titleID).inserted {
			guard row.currencyCode == currencyCode else { throw BudgetError.currency }
			if let amount = row.limitMinorUnits {
				values[row.titleID] = Money(minorUnits: amount, currencyCode: currencyCode)
			}
		}
		return values
	}
	private func validateTotals(_ context: ModelContext) throws {
		var expenseTotals: [String: Int] = [:]
		for expense in try context.fetch(FetchDescriptor<ExpenseModel>()) {
			guard expense.amountMinorUnits != Int.min else { throw BudgetError.invalidPayload }
			let key =
				expense.currencyCode + "/"
				+ String(CalendarMonth.containing(expense.date, using: calendar).key)
			let (sum, overflow) = (expenseTotals[key] ?? 0).addingReportingOverflow(
				abs(expense.amountMinorUnits))
			guard !overflow else { throw BudgetError.invalidPayload }
			expenseTotals[key] = sum
		}
		let limits = try context.fetch(FetchDescriptor<TitleLimitModel>())
		for monthKey in Set(limits.map(\.effectiveMonthKey)) {
			var latest: [UUID: TitleLimitModel] = [:]
			for limit in limits where limit.effectiveMonthKey <= monthKey {
				if latest[limit.titleID].map({ $0.effectiveMonthKey < limit.effectiveMonthKey }) ?? true
				{
					latest[limit.titleID] = limit
				}
			}
			var totals: [String: Int] = [:]
			for limit in latest.values {
				let amount = limit.limitMinorUnits ?? 0
				let (sum, overflow) = (totals[limit.currencyCode] ?? 0).addingReportingOverflow(amount)
				guard amount >= 0, !overflow else { throw BudgetError.invalidPayload }
				totals[limit.currencyCode] = sum
			}
		}
	}
	private func normalize(_ value: String) -> String {
		value.trimmingCharacters(in: .whitespacesAndNewlines).folding(
			options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es_PY"))
	}
	private func receiptKey(_ payload: SharePayload, fingerprint: String) -> String {
		if let budget = payload.budgetID, let revision = payload.revisionID {
			return budget.uuidString + "/" + revision.uuidString
		}
		return "legacy/" + fingerprint
	}
	private func hash(_ payload: SharePayload) throws -> String {
		let sorted = SharePayload(
			version: payload.version, currencyCode: payload.currencyCode, month: payload.month,
			titles: payload.titles.sorted { $0.id.uuidString < $1.id.uuidString },
			expenses: payload.expenses.sorted { $0.id.uuidString < $1.id.uuidString },
			budgetID: payload.budgetID, revisionID: payload.revisionID,
			includesExpenses: payload.includesExpenses, timeZoneIdentifier: payload.timeZoneIdentifier)
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.sortedKeys]
		return digest(try encoder.encode(sorted))
	}
	private func digest(_ data: Data) -> String { Data(SHA256.hash(data: data)).base64EncodedString() }
	/// Full local state fingerprint prevents committing decisions made against stale data.
	private func snapshot(_ context: ModelContext) throws -> String {
		var rows: [[String]] = []
		for t in try context.fetch(FetchDescriptor<ExpenseTitleModel>()) {
			rows.append(["title", t.id.uuidString, t.name, t.currencyCode])
		}
		for l in try context.fetch(FetchDescriptor<TitleLimitModel>()) {
			rows.append([
				"limit", l.id.uuidString, l.titleID.uuidString, String(l.effectiveMonthKey),
				l.limitMinorUnits.map(String.init) ?? "nil", l.currencyCode,
			])
		}
		for e in try context.fetch(FetchDescriptor<ExpenseModel>()) {
			rows.append([
				"expense", e.id.uuidString, e.titleID.uuidString, String(e.amountMinorUnits),
				e.currencyCode, String(e.date.timeIntervalSince1970), e.detail ?? "",
			])
		}
		for l in try context.fetch(FetchDescriptor<BudgetCategoryLinkModel>()) {
			rows.append(["link", l.key, l.localTitleID.uuidString])
		}
		for receipt in try context.fetch(FetchDescriptor<BudgetImportReceiptModel>()) {
			rows.append([
				"receipt", receipt.key, receipt.fingerprint,
				receipt.processedExpenseIDs.base64EncodedString(),
				receipt.decisions.base64EncodedString(),
			])
		}
		for s in try context.fetch(FetchDescriptor<BudgetSharingSelectionModel>()) {
			rows.append(["selection", s.key, s.budgetID.uuidString])
		}
		return digest(try JSONEncoder().encode(rows.sorted { $0.lexicographicallyPrecedes($1) }))
	}
}
