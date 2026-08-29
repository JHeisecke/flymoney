import Foundation

/// One row's words, bucketed by the column band their centre falls in.
/// Multiple words per column are space-joined in x order.
public struct RowCells: Equatable, Sendable {
    public let byColumn: [StatementColumn: String]
    /// Kept for diagnostics + balance assertions.
    public let row: TextRow

    public init(byColumn: [StatementColumn: String], row: TextRow) {
        self.byColumn = byColumn
        self.row = row
    }

    public subscript(_ column: StatementColumn) -> String? { byColumn[column] }
}

/// A row that survived shape classification and is awaiting a policy verdict.
public struct TransactionCandidate: Equatable, Sendable {
    public let cells: RowCells
    public let operationDate: Date
    public let rawDetail: String
    public let reference: String?
    public let amount: StatementAmount
    public let pageIndex: Int

    public init(
        cells: RowCells,
        operationDate: Date,
        rawDetail: String,
        reference: String?,
        amount: StatementAmount,
        pageIndex: Int
    ) {
        self.cells = cells
        self.operationDate = operationDate
        self.rawDetail = rawDetail
        self.reference = reference
        self.amount = amount
        self.pageIndex = pageIndex
    }
}

public struct StatementParseResult: Equatable, Sendable {
    public let transactions: [StatementTransaction]
    public let issues: [StatementParseIssue]

    public init(transactions: [StatementTransaction], issues: [StatementParseIssue]) {
        self.transactions = transactions
        self.issues = issues
    }
}

/// Kind-blind: the axis that varies between a card and an account statement —
/// how a row's amount resolves, and whether a row counts as spending — is
/// delegated to `StatementRowPolicy`. Everything else (header location, row
/// banding, column assignment, continuation, date parsing) is shared.
public protocol StatementRowParser: Sendable {
    func parse(pages: [TextPage], profile: StatementProfile) throws -> StatementParseResult
}

public struct DefaultStatementRowParser: StatementRowParser {
    private let kindDetector: StatementKindDetector
    private let profileMatcher: StatementProfileMatcher
    private let profileRepository: StatementProfileRepository

    public init(
        kindDetector: StatementKindDetector = DefaultStatementKindDetector(),
        profileMatcher: StatementProfileMatcher = DefaultStatementProfileMatcher(),
        profileRepository: StatementProfileRepository = BundledStatementProfileRepository()
    ) {
        self.kindDetector = kindDetector
        self.profileMatcher = profileMatcher
        self.profileRepository = profileRepository
    }

    /// Resolves kind and profile before parsing. `.unrecognisedDocumentKind` and
    /// `.noProfile(for:)` are distinct because the user's next action differs:
    /// "this isn't a statement" vs "this bank isn't supported yet".
    public func parse(pages: [TextPage]) async throws -> StatementParseResult {
        guard let kind = kindDetector.detectKind(pages: pages) else {
            throw StatementParseError.unrecognisedDocumentKind
        }
        let profiles = try await profileRepository.profiles(ofKind: kind)
        guard let profile = profileMatcher.match(pages: pages, among: profiles) else {
            throw StatementParseError.noProfile(for: kind)
        }
        return try parse(pages: pages, profile: profile)
    }

    public func parse(pages: [TextPage], profile: StatementProfile) throws -> StatementParseResult {
        let documentPeriod = try resolveDocumentPeriod(pages: pages, profile: profile)
        let policy = makePolicy(for: profile.rules)
        let sectionRules = sections(of: profile.rules)
        let deferredAmountRule = deferredAmount(of: profile.rules)
        let refundPrefixPatterns = refundPrefixes(of: profile.rules)

        var pushed: [(candidate: TransactionCandidate, section: SectionKind?)] = []
        var issues: [StatementParseIssue] = []
        var currentSection: SectionKind?
        var pending: PendingDeferred?
        var foundAnyTable = false

        for page in pages {
            let rows = Self.band(page.words, yTolerance: profile.yTolerance)
            guard let headerIndex = rows.firstIndex(where: { Self.isHeaderRow($0, patterns: profile.tableHeaderPatterns) }) else {
                continue
            }
            foundAnyTable = true

            for row in rows[(headerIndex + 1)...] {
                let cells = Self.cells(for: row, page: page, columns: profile.columns)
                let strippedText = row.words.map(\.text).joined()
                let date = Self.resolvedDate(cells, profile: profile, documentPeriod: documentPeriod)

                if let p = pending {
                    if let amount = policy.amount(from: cells, profile: profile) {
                        let candidate = TransactionCandidate(
                            cells: p.cells,
                            operationDate: p.operationDate,
                            rawDetail: p.rawDetail,
                            reference: p.reference,
                            amount: amount,
                            pageIndex: p.pageIndex
                        )
                        pushed.append((candidate, p.section))
                    } else {
                        issues.append(StatementParseIssue(kind: .deferredAmountNeverResolved, pageIndex: p.pageIndex, rowY: row.midY))
                    }
                    pending = nil
                    continue
                }

                // 1. Section header: no amount-bearing cell, no date, matches a SectionRule.
                if cells[.amount] == nil, cells[.debit] == nil, cells[.credit] == nil, date == nil,
                   let matched = Self.matchSection(strippedText, rules: sectionRules) {
                    currentSection = matched
                    continue
                }

                // 2. Continuation: only the detail band is populated, and it sits
                // close enough to the row it wraps. A band with no preceding row
                // at all is still an issue; one that is merely too far below its
                // row (a footer, not a wrap) falls through and is dropped
                // silently below, like any other non-table band.
                if cells.byColumn.count == 1, let detail = cells[.detail], !detail.isEmpty {
                    if let last = pushed.last {
                        if last.candidate.cells.row.midY - row.midY <= profile.continuationMaxGap {
                            let merged = last.candidate.rawDetail + " " + detail
                            let updated = TransactionCandidate(
                                cells: last.candidate.cells,
                                operationDate: last.candidate.operationDate,
                                rawDetail: merged,
                                reference: last.candidate.reference,
                                amount: last.candidate.amount,
                                pageIndex: last.candidate.pageIndex
                            )
                            pushed[pushed.count - 1] = (updated, last.section)
                            continue
                        }
                    } else {
                        issues.append(StatementParseIssue(kind: .continuationWithoutPrecedingRow, pageIndex: page.index, rowY: row.midY))
                        continue
                    }
                }

                // 3. Deferred-amount row: this profile's rule says the amount is on the next row.
                if Self.isDeferred(rule: deferredAmountRule, section: currentSection),
                   let date, let detail = cells[.detail], cells[.amount] == nil {
                    pending = PendingDeferred(operationDate: date, rawDetail: detail, reference: cells[.reference], cells: cells, pageIndex: page.index, section: currentSection)
                    continue
                }

                // 4. Transaction: a date parses and an amount resolves. Anything else is noise.
                if let date, let amount = policy.amount(from: cells, profile: profile) {
                    let candidate = TransactionCandidate(
                        cells: cells,
                        operationDate: date,
                        rawDetail: cells[.detail] ?? "",
                        reference: cells[.reference],
                        amount: amount,
                        pageIndex: page.index
                    )
                    pushed.append((candidate, currentSection))
                }
            }
        }

        if let p = pending {
            issues.append(StatementParseIssue(kind: .deferredAmountNeverResolved, pageIndex: p.pageIndex, rowY: p.cells.row.midY))
        }

        guard foundAnyTable else { throw StatementParseError.noTableFound(profileID: profile.id) }

        let transactions = pushed.compactMap { candidate, section -> StatementTransaction? in
            let verdict = policy.verdict(for: candidate, section: section)
            guard verdict != .skip else { return nil }
            return StatementTransaction(
                profileID: profile.id,
                operationDate: candidate.operationDate,
                rawDetail: candidate.rawDetail,
                normalizedDetail: DetailNormalizer.normalize(candidate.rawDetail, refundPrefixPatterns: refundPrefixPatterns),
                reference: candidate.reference,
                amount: candidate.amount,
                sectionKind: section,
                isRefund: candidate.amount.minorUnits < 0,
                isAmbiguous: verdict == .keepFlaggedAmbiguous,
                pageIndex: candidate.pageIndex
            )
        }

        return StatementParseResult(transactions: transactions, issues: issues)
    }

    // MARK: - Document period

    private func resolveDocumentPeriod(pages: [TextPage], profile: StatementProfile) throws -> DocumentPeriod? {
        guard let rule = profile.documentPeriod else { return nil }
        let fullText = pages.first.map { $0.words.map(\.text).joined(separator: " ") } ?? ""
        guard let period = DateResolver.extractDocumentPeriod(fullText: fullText, rule: rule, timeZoneIdentifier: profile.timeZoneIdentifier) else {
            throw StatementParseError.missingDocumentPeriod(profileID: profile.id)
        }
        return period
    }

    // MARK: - Policy selection

    private func makePolicy(for rules: StatementRules) -> StatementRowPolicy {
        switch rules {
        case .creditCard(let rules): CreditCardRowPolicy(rules: rules)
        case .bankAccount(let rules): BankAccountRowPolicy(rules: rules)
        }
    }

    private func sections(of rules: StatementRules) -> [SectionRule] {
        if case .creditCard(let rules) = rules { return rules.sections }
        return []
    }

    private func deferredAmount(of rules: StatementRules) -> DeferredAmountRule? {
        if case .creditCard(let rules) = rules { return rules.deferredAmount }
        return nil
    }

    private static func isDeferred(rule: DeferredAmountRule?, section: SectionKind?) -> Bool {
        switch rule {
        case .sections(let sections):
            guard let section else { return false }
            return sections.contains(section)
        case .anyRowWithoutAmount:
            return true
        case nil:
            return false
        }
    }

    private func refundPrefixes(of rules: StatementRules) -> [String] {
        if case .creditCard(let rules) = rules { return rules.refundPrefixPatterns }
        return []
    }

    // MARK: - Row banding

    static func band(_ words: [PositionedWord], yTolerance: Double) -> [TextRow] {
        var lines: [[PositionedWord]] = []
        for word in words {
            if let referenceY = lines.last?.first?.midY, abs(referenceY - word.midY) <= yTolerance {
                lines[lines.count - 1].append(word)
            } else {
                lines.append([word])
            }
        }
        return lines.map { line in
            TextRow(midY: line[0].midY, words: line.sorted { $0.minX < $1.minX })
        }
    }

    // MARK: - Column assignment

    static func cells(for row: TextRow, page: TextPage, columns: [ColumnBand]) -> RowCells {
        var byColumn: [StatementColumn: [PositionedWord]] = [:]
        for word in row.words {
            guard page.width > 0 else { continue }
            let fraction = word.centerX / page.width
            guard let band = columns.first(where: { fraction >= $0.start && fraction <= $0.end }) else { continue }
            byColumn[band.column, default: []].append(word)
        }
        let joined = byColumn.mapValues { words in
            words.sorted { $0.minX < $1.minX }.map(\.text).joined(separator: " ")
        }
        return RowCells(byColumn: joined, row: row)
    }

    // MARK: - Header location

    static func isHeaderRow(_ row: TextRow, patterns: [String]) -> Bool {
        let stripped = row.words.map(\.text).joined()
        return patterns.allSatisfy { stripped.contains($0) }
    }

    // MARK: - Section matching

    static func matchSection(_ strippedText: String, rules: [SectionRule]) -> SectionKind? {
        for rule in rules {
            guard let regex = try? NSRegularExpression(pattern: rule.pattern) else { continue }
            let range = NSRange(strippedText.startIndex..., in: strippedText)
            if regex.firstMatch(in: strippedText, range: range) != nil {
                return rule.kind
            }
        }
        return nil
    }

    // MARK: - Date resolution

    static func resolvedDate(_ cells: RowCells, profile: StatementProfile, documentPeriod: DocumentPeriod?) -> Date? {
        guard let raw = cells[.operationDate], !raw.isEmpty else { return nil }
        return DateResolver.resolveDate(
            raw,
            dateFormat: profile.dateFormat,
            timeZoneIdentifier: profile.timeZoneIdentifier,
            documentPeriod: documentPeriod
        )
    }
}

private struct PendingDeferred {
    let operationDate: Date
    let rawDetail: String
    let reference: String?
    let cells: RowCells
    let pageIndex: Int
    let section: SectionKind?
}
