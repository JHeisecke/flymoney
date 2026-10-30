//
//  BudgetRepositoryTests.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-10-30.
//

import Foundation
import SwiftData
import Testing

@testable import flymoney

@MainActor
@Suite("Shared monthly budgets", .serialized, .tags(.persistence))
struct BudgetRepositoryTests {
	private let month = CalendarMonth(year: 2026, month: 11)
	private func make(url: URL? = nil) throws -> (ModelContainer, SwiftDataBudgetRepository) {
		let container: ModelContainer
		if let url {
			container = try ModelContainer(
				for: ModelSchema.schema, migrationPlan: ModelMigrationPlan.self,
				configurations: ModelConfiguration(schema: ModelSchema.schema, url: url))
		} else {
			container = try SwiftDataStack.makeInMemoryContainer()
		}
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
		return (
			container,
			SwiftDataBudgetRepository(modelContainer: container, currencyCode: "PYG", calendar: calendar)
		)
	}
	private func payload(_ profile: BudgetProfile = .javier) throws -> SharePayload {
		try BundledBudgetTemplateRepository().load().payload(profile: profile, month: month)
	}
	@Test("Closed catalog has exact personal amounts and no zero entries")
	func catalog() throws {
		let template = try BundledBudgetTemplateRepository().load()
		let iara = template.payload(profile: .iara, month: month)
		let javier = template.payload(profile: .javier, month: month)
		#expect(iara.titles.count == 12 && javier.titles.count == 18)
		#expect(iara.titles.reduce(0) { $0 + ($1.limitMinorUnits ?? 0) } == 5_617_482)
		#expect(javier.titles.reduce(0) { $0 + ($1.limitMinorUnits ?? 0) } == 21_932_107)
		#expect(iara.titles.first { $0.name == "Ahorro" }?.limitMinorUnits == 1_000_000)
		#expect(javier.titles.first { $0.name == "Préstamo" }?.limitMinorUnits == 5_000_000)
		#expect(!iara.titles.contains { $0.name == "Préstamo" })
		#expect(!template.entries.contains { ["Regalos", "IVA", "Contador"].contains($0.name) })
		#expect((iara.titles + javier.titles).allSatisfy { ($0.limitMinorUnits ?? 0) > 0 })
	}
	@Test("Loading and reloading creates limits, never expenses or duplicate categories")
	func loadTwice() async throws {
		let (container, repo) = try make()
		let original = try payload()
		try await repo.commit(repo.prepare(original))
		try await repo.commit(repo.prepare(original))
		let context = ModelContext(container)
		#expect(try context.fetchCount(FetchDescriptor<ExpenseModel>()) == 0)
		#expect(try context.fetchCount(FetchDescriptor<ExpenseTitleModel>()) == 18)
		#expect(try context.fetchCount(FetchDescriptor<TitleLimitModel>()) == 18)
		let december = try await repo.export(
			month: CalendarMonth(year: 2026, month: 12), includesExpenses: false)
		#expect(december.titles.count == 18 && december.expenses.isEmpty)
		#expect(december.budgetID == original.budgetID)
		let october = try await repo.export(
			month: CalendarMonth(year: 2026, month: 10), includesExpenses: false)
		#expect(october.titles.isEmpty)
	}
	@Test("Two stores preserve personal limits, expense IDs, and A to B to A identity")
	func roundTrip() async throws {
		let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		defer { try? FileManager.default.removeItem(at: directory) }
		let aURL = directory.appending(path: "a.sqlite")
		let bURL = directory.appending(path: "b.sqlite")
		let (a, sender) = try make(url: aURL)
		let (b, receiver) = try make(url: bURL)
		try await sender.commit(sender.prepare(payload(.javier)))
		let localB = ModelContext(b)
		let personalID = UUID()
		localB.insert(
			ExpenseTitleModel(id: personalID, name: "Combustible", currencyCode: "PYG", createdAt: .now))
		localB.insert(
			TitleLimitModel(
				titleID: personalID, effectiveMonthKey: month.key, limitMinorUnits: 400_000,
				currencyCode: "PYG"))
		try localB.save()
		try await receiver.commit(receiver.prepare(payload(.iara)))
		let context = ModelContext(a)
		let local = try #require(
			context.fetch(FetchDescriptor<ExpenseTitleModel>()).first { $0.name == "Combustible" })
		let expenseID = UUID()
		context.insert(
			ExpenseModel(
				id: expenseID, amountMinorUnits: 50_000, currencyCode: "PYG", titleID: local.id,
				date: month.interval(using: .current).start.addingTimeInterval(86400),
				detail: "Private note"))
		try context.save()
		let limitsOnly = try await sender.export(month: month, includesExpenses: false)
		#expect(limitsOnly.expenses.isEmpty && limitsOnly.includesExpenses == false)
		let withExpenses = try await sender.export(month: month, includesExpenses: true)
		#expect(withExpenses.expenses.first?.id == expenseID)
		#expect(try SharePayloadCodec.decode(SharePayloadCodec.encode(withExpenses)) == withExpenses)
		let review = try await receiver.prepare(withExpenses)
		try await receiver.commit(review)
		try await receiver.commit(receiver.prepare(withExpenses))
		let renamed = try #require(
			localB.fetch(FetchDescriptor<ExpenseTitleModel>()).first { $0.id == personalID })
		renamed.name = "Mi combustible"
		try localB.save()
		let back = try await receiver.export(month: month, includesExpenses: true)
		#expect(back.budgetID == withExpenses.budgetID)
		#expect(back.titles.first { $0.name == "Mi combustible" }?.limitMinorUnits == 400_000)
		try await sender.commit(sender.prepare(back))
		#expect(try ModelContext(a).fetchCount(FetchDescriptor<ExpenseModel>()) == 1)
		#expect(try ModelContext(b).fetchCount(FetchDescriptor<ExpenseModel>()) == 1)
		#expect(try ModelContext(a).fetch(FetchDescriptor<ExpenseModel>()).first?.detail == "Private note")
		let (reopenedA, senderAgain) = try make(url: aURL)
		let (reopenedB, receiverAgain) = try make(url: bURL)
		#expect(try ModelContext(reopenedA).fetch(FetchDescriptor<ExpenseModel>()).first?.id == expenseID)
		#expect(try ModelContext(reopenedB).fetch(FetchDescriptor<ExpenseModel>()).first?.id == expenseID)
		#expect(try ModelContext(reopenedB).fetchCount(FetchDescriptor<BudgetImportReceiptModel>()) == 2)
		let repeated = try await receiverAgain.prepare(withExpenses)
		#expect(repeated.knownPlan && repeated.newExpenseCount == 0)
		try await receiverAgain.commit(repeated)
		let afterRestart = try await senderAgain.export(month: month, includesExpenses: true)
		#expect(afterRestart.budgetID == withExpenses.budgetID)
		#expect(afterRestart.expenses.first?.titleID == withExpenses.expenses.first?.titleID)

	}
	@Test("Adopting a received limit preserves previous and scheduled future months")
	func timeline() async throws {
		let (container, repo) = try make()
		let original = try payload(.iara)
		try await repo.commit(repo.prepare(original))
		let context = ModelContext(container)
		let title = try #require(
			context.fetch(FetchDescriptor<ExpenseTitleModel>()).first { $0.name == "Combustible" })
		context.insert(
			TitleLimitModel(
				titleID: title.id, effectiveMonthKey: CalendarMonth(year: 2026, month: 10).key,
				limitMinorUnits: 100, currencyCode: "PYG"))
		context.insert(
			TitleLimitModel(
				titleID: title.id, effectiveMonthKey: CalendarMonth(year: 2027, month: 1).key,
				limitMinorUnits: 200, currencyCode: "PYG"))
		try context.save()
		var review = try await repo.prepare(payload(.javier))
		let index = try #require(review.rows.firstIndex { $0.name == "Combustible" })
		review.rows[index].useIncomingLimit = true
		try await repo.commit(review)
		let november = try await repo.export(month: month, includesExpenses: false)
		let october = try await repo.export(
			month: CalendarMonth(year: 2026, month: 10), includesExpenses: false)
		let january = try await repo.export(month: CalendarMonth(year: 2027, month: 1), includesExpenses: false)
		#expect(november.titles.first { $0.name == "Combustible" }?.limitMinorUnits == 600_000)
		#expect(october.titles.first { $0.name == "Combustible" }?.limitMinorUnits == 100)
		#expect(january.titles.first { $0.name == "Combustible" }?.limitMinorUnits == 200)
	}
	@Test("Staged failure rolls back and a subsequent commit on the same writer succeeds")
	func rollback() async throws {
		enum Failure: Error { case injected }
		let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		defer { try? FileManager.default.removeItem(at: directory) }
		let url = directory.appending(path: "rollback.sqlite")
		let (container, repo) = try make(url: url)
		let review = try await repo.prepare(payload())
		await #expect(throws: Failure.self) {
			try await repo.commit(review, beforeSave: { throw Failure.injected })
		}
		#expect(try ModelContext(container).fetchCount(FetchDescriptor<ExpenseTitleModel>()) == 0)
		#expect(try ModelContext(container).fetchCount(FetchDescriptor<BudgetImportReceiptModel>()) == 0)
		let (reopened, _) = try make(url: url)
		#expect(try ModelContext(reopened).fetchCount(FetchDescriptor<ExpenseTitleModel>()) == 0)
		#expect(try ModelContext(reopened).fetchCount(FetchDescriptor<BudgetPlanModel>()) == 0)
		try await repo.commit(review)
		#expect(try ModelContext(container).fetchCount(FetchDescriptor<ExpenseTitleModel>()) == 18)
	}
	@Test("Changed local data requires refreshing the review")
	func staleReview() async throws {
		let (container, repo) = try make()
		let review = try await repo.prepare(payload())
		let context = ModelContext(container)
		context.insert(ExpenseTitleModel(id: UUID(), name: "New local", currencyCode: "PYG", createdAt: .now))
		try context.save()
		await #expect(throws: BudgetError.self) { try await repo.commit(review) }
		#expect(try ModelContext(container).fetchCount(FetchDescriptor<TitleLimitModel>()) == 0)
	}
	@Test("Currency mismatch cannot reinterpret the template as dollars")
	func currencyMismatch() async throws {
		let (container, _) = try make()
		let repo = SwiftDataBudgetRepository(modelContainer: container, currencyCode: "USD")
		await #expect(throws: BudgetError.self) { try await repo.prepare(payload()) }
		#expect(try ModelContext(container).fetchCount(FetchDescriptor<ExpenseTitleModel>()) == 0)
	}
	@Test("Same revision cannot change content and deleted imported expenses do not return")
	func receiptIntegrity() async throws {
		let (container, repo) = try make()
		let original = try payload()
		let title = try #require(original.titles.first)
		let expense = SharePayload.ExpenseDTO(
			id: UUID(), titleID: title.id, amountMinorUnits: 100,
			date: month.interval(using: .current).start.addingTimeInterval(86400))
		let transfer = SharePayload(
			version: 2, currencyCode: "PYG", month: month, titles: original.titles, expenses: [expense],
			budgetID: original.budgetID, revisionID: original.revisionID, includesExpenses: true,
			timeZoneIdentifier: TimeZone.current.identifier)
		try await repo.commit(repo.prepare(transfer))
		let context = ModelContext(container)
		for expense in try context.fetch(FetchDescriptor<ExpenseModel>()) { context.delete(expense) }
		try context.save()
		let repeatReview = try await repo.prepare(transfer)
		#expect(repeatReview.newExpenseCount == 0)
		try await repo.commit(repeatReview)
		#expect(try ModelContext(container).fetchCount(FetchDescriptor<ExpenseModel>()) == 0)
		await #expect(throws: BudgetError.self) { try await repo.prepare(original) }
	}

	@Test("Existing changed expense is kept, nil limit is explicit, and revision decisions can change")
	func preserveExpenseAndClearLimit() async throws {
		let (container, repo) = try make()
		let original = try payload()
		try await repo.commit(repo.prepare(original))
		let context = ModelContext(container)
		let local = try #require(context.fetch(FetchDescriptor<ExpenseTitleModel>()).first)
		let expenseID = UUID()
		let date = month.interval(using: .current).start.addingTimeInterval(86400)
		context.insert(
			ExpenseModel(
				id: expenseID, amountMinorUnits: 500, currencyCode: "PYG", titleID: local.id,
				date: date, detail: "local note"))
		try context.save()
		let outbound = try await repo.export(month: month, includesExpenses: true)
		let remoteTitle = try #require(outbound.titles.first { $0.name == local.name })
		let changed = SharePayload(
			version: 2, currencyCode: "PYG", month: month,
			titles: [.init(id: remoteTitle.id, name: local.name, limitMinorUnits: nil)],
			expenses: [.init(id: expenseID, titleID: remoteTitle.id, amountMinorUnits: 999, date: date)],
			budgetID: outbound.budgetID, revisionID: UUID(), includesExpenses: true,
			timeZoneIdentifier: TimeZone.current.identifier)
		var review = try await repo.prepare(changed)
		#expect(review.conflictingExpenseIDs == [expenseID])
		#expect(review.newExpenseCount == 0)
		try await repo.commit(review)
		let afterKeep = try await repo.export(month: month, includesExpenses: true)
		#expect(afterKeep.titles.first { $0.name == local.name }?.limitMinorUnits != nil)
		review = try await repo.prepare(changed)
		review.rows[0].useIncomingLimit = true
		try await repo.commit(review)
		let afterClear = try await repo.export(month: month, includesExpenses: true)
		#expect(afterClear.titles.first { $0.name == local.name }?.limitMinorUnits == nil)
		let stored = try #require(ModelContext(container).fetch(FetchDescriptor<ExpenseModel>()).first)
		#expect(stored.amountMinorUnits == 500 && stored.detail == "local note")
	}
	@Test("Distinct concept rows cannot overwrite the same local category")
	func duplicateMapping() async throws {
		let (container, repo) = try make()
		let context = ModelContext(container)
		let id = UUID()
		context.insert(ExpenseTitleModel(id: id, name: "Local", currencyCode: "PYG", createdAt: .now))
		try context.save()
		var review = try await repo.prepare(payload())
		review.rows[0].localTitleID = id
		review.rows[1].localTitleID = id
		await #expect(throws: BudgetError.self) { try await repo.commit(review) }
		#expect(try ModelContext(container).fetchCount(FetchDescriptor<TitleLimitModel>()) == 0)
	}

	@Test("Share preview creates no durable identities or receipts")
	func previewIsReadOnly() async throws {
		let (container, repo) = try make()
		_ = try await repo.preview(month: month, includesExpenses: false)
		let context = ModelContext(container)
		#expect(try context.fetchCount(FetchDescriptor<BudgetPlanModel>()) == 0)
		#expect(try context.fetchCount(FetchDescriptor<BudgetSharingSelectionModel>()) == 0)
		#expect(try context.fetchCount(FetchDescriptor<BudgetImportReceiptModel>()) == 0)
	}
	@Test("A cancelled commit saves nothing")
	func cancelledCommit() async throws {
		let (container, repo) = try make()
		let draft = try payload()
		let review = try await repo.prepare(draft)
		let task = Task { try await repo.commit(review) }
		task.cancel()
		await #expect(throws: CancellationError.self) { try await task.value }
		#expect(try ModelContext(container).fetchCount(FetchDescriptor<ExpenseTitleModel>()) == 0)
	}

	@Test("Share modes include the right categories and preserve independent equal expenses")
	func exportModes() async throws {
		let (source, sender) = try make()
		let (target, receiver) = try make()
		let context = ModelContext(source)
		let limitID = UUID()
		let spentID = UUID()
		context.insert(ExpenseTitleModel(id: limitID, name: "Limit only", currencyCode: "PYG", createdAt: .now))
		context.insert(
			ExpenseTitleModel(id: spentID, name: "Expenses only", currencyCode: "PYG", createdAt: .now))
		context.insert(
			TitleLimitModel(
				titleID: limitID, effectiveMonthKey: month.key, limitMinorUnits: 123,
				currencyCode: "PYG"))
		let date = month.interval(using: .current).start.addingTimeInterval(86400)
		for _ in 0..<2 {
			context.insert(
				ExpenseModel(
					id: UUID(), amountMinorUnits: 50, currencyCode: "PYG", titleID: spentID,
					date: date))
		}
		try context.save()
		let limits = try await sender.export(month: month, includesExpenses: false)
		#expect(limits.titles.map(\.id) == [limitID] && limits.expenses.isEmpty)
		let all = try await sender.export(month: month, includesExpenses: true)
		#expect(Set(all.titles.map(\.id)) == [limitID, spentID])
		try await receiver.commit(receiver.prepare(all))
		let received = ModelContext(target)
		#expect(try received.fetchCount(FetchDescriptor<ExpenseModel>()) == 2)
		let receipt = try #require(received.fetch(FetchDescriptor<BudgetImportReceiptModel>()).first)
		let record = try JSONDecoder().decode(BudgetReceiptRecord.self, from: receipt.decisions)
		#expect(record.version == 1 && record.month == month && record.includesExpenses)
		#expect(record.choices.count == 2)
	}
	@Test("Malformed budget references, duplicates, dates and arithmetic overflow are rejected")
	func payloadSafety() throws {
		let id = UUID()
		let date = month.interval(using: .current).start.addingTimeInterval(86400)
		let title = SharePayload.TitleDTO(id: id, name: "Test", limitMinorUnits: 100)
		let expense = SharePayload.ExpenseDTO(id: UUID(), titleID: id, amountMinorUnits: 10, date: date)
		func pack(
			_ titles: [SharePayload.TitleDTO], _ expenses: [SharePayload.ExpenseDTO] = [],
			includes: Bool = true
		) -> SharePayload {
			SharePayload(
				version: 2, currencyCode: "PYG", month: month, titles: titles, expenses: expenses,
				budgetID: UUID(), revisionID: UUID(), includesExpenses: includes,
				timeZoneIdentifier: TimeZone.current.identifier)
		}
		let invalid = [
			pack([title, title]), pack([title], [expense, expense]),
			pack([], [expense]), pack([title], [expense], includes: false),
			pack([
				.init(id: id, name: "A", limitMinorUnits: Int.max),
				.init(id: UUID(), name: "B", limitMinorUnits: 1),
			]),
			pack([title], [.init(id: UUID(), titleID: id, amountMinorUnits: Int.min, date: date)]),
			pack([title], [.init(id: UUID(), titleID: id, amountMinorUnits: 10, date: .distantPast)]),
		]
		for payload in invalid {
			#expect(throws: BudgetError.self) { try BudgetPayloadValidation.validate(payload) }
		}
		try BudgetPayloadValidation.validate(pack([title], [expense]))
	}
	@Test("Legacy payloads remain readable while malformed references are rejected")
	func legacyAndValidation() async throws {
		let (_, repo) = try make()
		let id = UUID()
		let legacy = SharePayload(
			version: 1, currencyCode: "PYG", month: month,
			titles: [.init(id: id, name: "Coffee", limitMinorUnits: 100)], expenses: [])
		try await repo.commit(repo.prepare(legacy))
		let invalid = SharePayload(
			version: 1, currencyCode: "PYG", month: month, titles: [],
			expenses: [.init(id: UUID(), titleID: id, amountMinorUnits: 100, date: .now)])
		#expect(throws: BudgetError.self) { try SharePayloadCodec.decode(SharePayloadCodec.encode(invalid)) }
	}
}
