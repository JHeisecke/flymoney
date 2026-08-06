//
//  ParseStatementUseCase.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-08-05.
//

import Foundation
import StatementParsing

/// Read-only: writes nothing. `CommitStatementImportUseCase` is the only writer.
protocol ParseStatementUseCase: Sendable {
	/// `profileID == nil` means "detect": kind first, then profile within that kind.
	func execute(fileURL: URL, profileID: String?) async throws -> StatementImportDraft
}

struct ParseStatementUseCaseImpl: ParseStatementUseCase {
	let extractor: StatementTextExtracting
	let kindDetector: StatementKindDetector
	let profileMatcher: StatementProfileMatcher
	let profileRepository: StatementProfileRepository
	let rowParser: StatementRowParser
	let expenses: ExpenseRepository
	let titles: ExpenseTitleRepository
	let aliases: TitleAliasRepository
	let currencyProvider: CurrencyProvider
	let calendar: Calendar

	init(
		extractor: StatementTextExtracting,
		kindDetector: StatementKindDetector,
		profileMatcher: StatementProfileMatcher,
		profileRepository: StatementProfileRepository,
		rowParser: StatementRowParser,
		expenses: ExpenseRepository,
		titles: ExpenseTitleRepository,
		aliases: TitleAliasRepository,
		currencyProvider: CurrencyProvider,
		calendar: Calendar = .current
	) {
		self.extractor = extractor
		self.kindDetector = kindDetector
		self.profileMatcher = profileMatcher
		self.profileRepository = profileRepository
		self.rowParser = rowParser
		self.expenses = expenses
		self.titles = titles
		self.aliases = aliases
		self.currencyProvider = currencyProvider
		self.calendar = calendar
	}

	func execute(fileURL: URL, profileID: String?) async throws -> StatementImportDraft {
		let pages = try await extractor.extract(fileURL: fileURL, gapTolerance: 2.5)
		let profile = try await resolveProfile(pages: pages, profileID: profileID)

		let parseResult = try rowParser.parse(pages: pages, profile: profile)

		try StatementImportMapper.requireMatchingCurrency(profile.currencyCode, appCurrency: currencyProvider.defaultCurrencyCode)

		let mapped = parseResult.transactions.map { transaction in
			MappedTransaction(
				transaction: transaction,
				money: StatementImportMapper.money(from: transaction.amount),
				fingerprint: StatementImportMapper.fingerprint(
					profileID: profile.id,
					date: transaction.operationDate,
					minorUnits: transaction.amount.minorUnits,
					normalizedDetail: transaction.normalizedDetail,
					reference: transaction.reference
				)
			)
		}

		guard !mapped.isEmpty else {
			return StatementImportDraft(
				profileID: profile.id, profileDisplayName: profile.displayName, bankID: profile.bankID,
				kind: profile.kind, sourceFileName: fileURL.lastPathComponent, currencyCode: profile.currencyCode,
				groups: [], months: [], issues: parseResult.issues
			)
		}

		let existingFingerprints = try await expenses.existingFingerprints(mapped.map(\.fingerprint))
		let digestsByDayAndAmount = try await digestsByDayAndAmount(for: mapped)
		let titleNames = try await titleNamesByID()
		let aliasesByNormalizedDetail = try await aliases.aliases(forNormalizedDetails: Array(Set(mapped.map { $0.transaction.normalizedDetail })))

		let rows = mapped.map { entry -> (normalizedDetail: String, row: StatementImportRow) in
			let transaction = entry.transaction
			let alreadyImported = existingFingerprints.contains(entry.fingerprint)
			var possibleDuplicate: PossibleDuplicate?
			if !alreadyImported {
				let key = DigestKey(day: transaction.operationDate.startOfDay(in: calendar), minorUnits: transaction.amount.minorUnits)
				if let match = digestsByDayAndAmount[key]?.first {
					possibleDuplicate = PossibleDuplicate(
						expenseID: match.id, titleName: titleNames[match.titleID] ?? "", wasImported: match.isImported
					)
				}
			}
			let row = StatementImportRow(
				id: transaction.id, date: transaction.operationDate, amount: entry.money,
				rawDetail: transaction.rawDetail, reference: transaction.reference, fingerprint: entry.fingerprint,
				alreadyImported: alreadyImported, possibleDuplicate: possibleDuplicate,
				isRefund: transaction.isRefund, isAmbiguous: transaction.isAmbiguous
			)
			return (transaction.normalizedDetail, row)
		}

		let groups = groupByNormalizedDetail(rows, mapped: mapped, suggestions: aliasesByNormalizedDetail)
		let months = Set(mapped.map { CalendarMonth.containing($0.transaction.operationDate, using: calendar) })
			.sorted { $0.key < $1.key }

		return StatementImportDraft(
			profileID: profile.id, profileDisplayName: profile.displayName, bankID: profile.bankID,
			kind: profile.kind, sourceFileName: fileURL.lastPathComponent, currencyCode: profile.currencyCode,
			groups: groups, months: months, issues: parseResult.issues
		)
	}

	// MARK: - Profile resolution

	private func resolveProfile(pages: [TextPage], profileID: String?) async throws -> StatementProfile {
		if let profileID {
			guard let found = try await profileRepository.profile(id: profileID) else {
				throw StatementImportError.unknownProfile(id: profileID)
			}
			return found
		}
		guard let kind = kindDetector.detectKind(pages: pages) else {
			throw StatementParseError.unrecognisedDocumentKind
		}
		let candidates = try await profileRepository.profiles(ofKind: kind)
		guard let matched = profileMatcher.match(pages: pages, among: candidates) else {
			throw StatementParseError.noProfile(for: kind)
		}
		return matched
	}

	// MARK: - Possible-duplicate matching

	private struct DigestKey: Hashable {
		let day: Date
		let minorUnits: Int
	}

	private func digestsByDayAndAmount(for mapped: [MappedTransaction]) async throws -> [DigestKey: [ExpenseDigest]] {
		let dates = mapped.map(\.transaction.operationDate)
		guard let minDate = dates.min(), let maxDate = dates.max() else { return [:] }
		let start = minDate.startOfDay(in: calendar)
		let end = calendar.date(byAdding: .day, value: 1, to: maxDate.startOfDay(in: calendar)) ?? maxDate
		let digests = try await expenses.expenseDigests(in: DateInterval(start: start, end: end))

		var byKey: [DigestKey: [ExpenseDigest]] = [:]
		for digest in digests {
			let key = DigestKey(day: digest.date.startOfDay(in: calendar), minorUnits: digest.amountMinorUnits)
			byKey[key, default: []].append(digest)
		}
		return byKey
	}

	private func titleNamesByID() async throws -> [UUID: String] {
		Dictionary(uniqueKeysWithValues: try await titles.allTitles().map { ($0.id, $0.name) })
	}

	// MARK: - Grouping

	private struct MappedTransaction {
		let transaction: StatementTransaction
		let money: Money
		let fingerprint: String
	}

	private func groupByNormalizedDetail(
		_ rows: [(normalizedDetail: String, row: StatementImportRow)],
		mapped: [MappedTransaction],
		suggestions: [String: TitleAlias]
	) -> [StatementImportGroup] {
		var rowsByKey: [String: [StatementImportRow]] = [:]
		var rawDetailByKey: [String: String] = [:]
		var order: [String] = []
		for (index, entry) in rows.enumerated() {
			let key = entry.normalizedDetail
			if rowsByKey[key] == nil {
				order.append(key)
				rawDetailByKey[key] = mapped[index].transaction.rawDetail
			}
			rowsByKey[key, default: []].append(entry.row)
		}
		return order.map { key in
			StatementImportGroup(
				id: key,
				rawDetail: rawDetailByKey[key] ?? key,
				suggestedTitleID: suggestions[key]?.titleID,
				rows: rowsByKey[key] ?? []
			)
		}
	}
}
