import Testing
import Foundation
@testable import StatementParsing

@Suite("continental-cuenta end-to-end")
struct ContinentalCuentaTests {
    /// The bank prints its own column totals on the `Totales` line. Asserting
    /// against those rather than against a hand-counted expectation means the
    /// document itself is the oracle — a banding or rule mistake has to agree
    /// with Banco Continental's arithmetic to go unnoticed.
    private static let printedDebitTotal = 4_414_900
    private static let printedCreditTotal = 4_458_495

    private func loadProfile() async throws -> StatementProfile {
        try #require(await BundledStatementProfileRepository().profile(id: "continental-cuenta"))
    }

    private func parse() async throws -> StatementParseResult {
        let pages = try TestFixtures.pages("continental-cuenta-pages")
        return try DefaultStatementRowParser().parse(pages: pages, profile: await loadProfile())
    }

    @Test("10 outgoing transfers, summing to the Debe total the bank printed")
    func totalsAndCount() async throws {
        let result = try await parse()
        #expect(result.transactions.count == 10)
        #expect(result.issues.isEmpty)
        #expect(result.transactions.allSatisfy { $0.amount.minorUnits > 0 })
        #expect(result.transactions.reduce(0) { $0 + $1.amount.minorUnits } == Self.printedDebitTotal)
        #expect(result.transactions.allSatisfy { $0.amount.currencyCode == "PYG" })
    }

    @Test("incoming transfers and deposits are excluded")
    func creditRowsExcluded() async throws {
        let result = try await parse()
        #expect(result.transactions.allSatisfy { $0.rawDetail.hasPrefix("TRANS.INTERB.") })
        #expect(!result.transactions.contains { $0.rawDetail.contains("TRF.INTRBN.") })
        #expect(!result.transactions.contains { $0.rawDetail.contains("lote") })
    }

    @Test("every imported row is flagged ambiguous, none is a refund")
    func ambiguousFlagging() async throws {
        let result = try await parse()
        // An interbank transfer's payee is printed nowhere on the statement, so
        // all ten need the user's eyes on the review screen — same reasoning as
        // `gnb-cuenta`'s `Transferencia enviada`.
        #expect(result.transactions.allSatisfy { $0.isAmbiguous })
        #expect(result.transactions.allSatisfy { !$0.isRefund })
    }

    @Test("bare day-of-month dates resolve to the document period's month, not January")
    func datesResolveAgainstDocumentPeriodMonth() async throws {
        let result = try await parse()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Asuncion"))
        #expect(result.transactions.allSatisfy { calendar.component(.year, from: $0.operationDate) == 2026 })
        #expect(result.transactions.allSatisfy { calendar.component(.month, from: $0.operationDate) == 8 })
        #expect(Set(result.transactions.map { calendar.component(.day, from: $0.operationDate) })
            == [5, 7, 10, 11, 21, 25])
    }

    @Test("Saldo is never emitted as an amount, despite being the rightmost number on every row")
    func balanceNeverImported() async throws {
        let pages = try TestFixtures.pages("continental-cuenta-pages")
        let profile = try await loadProfile()
        let result = try DefaultStatementRowParser().parse(pages: pages, profile: profile)

        var balances: Set<Int> = []
        for page in pages {
            for row in DefaultStatementRowParser.band(page.words, yTolerance: profile.yTolerance) {
                let cells = DefaultStatementRowParser.cells(for: row, page: page, columns: profile.columns)
                guard let raw = cells[.balance] else { continue }
                if let value = AmountParser.parseMinorUnits(
                    raw,
                    groupingSeparator: profile.groupingSeparator,
                    decimalSeparator: profile.decimalSeparator,
                    exponent: 0
                ) {
                    balances.insert(value)
                }
            }
        }
        #expect(!balances.isEmpty)
        #expect(Set(result.transactions.map(\.amount.minorUnits)).isDisjoint(with: balances))
    }

    @Test("the Totales footer line never becomes a transaction")
    func totalsRowNeverImported() async throws {
        let result = try await parse()
        let amounts = Set(result.transactions.map(\.amount.minorUnits))
        // Both figures sit in the debit and credit bands with no parseable Dia,
        // so they must be dropped before the amount step rather than competing
        // with a real row.
        #expect(!amounts.contains(Self.printedDebitTotal))
        #expect(!amounts.contains(Self.printedCreditTotal))
        #expect(!result.transactions.contains { $0.rawDetail.contains("Totales") })
    }

    @Test("the Hora column is dropped, not folded into a neighbouring cell")
    func timeColumnDropped() async throws {
        let result = try await parse()
        // `Hora` has no band, so its words fall in no column and are discarded.
        // If the operationDate or reference band ever widened over it, a time
        // string would appear in a detail or reference cell.
        #expect(!result.transactions.contains { $0.rawDetail.contains(":") })
        #expect(!result.transactions.contains { ($0.reference ?? "").contains(":") })
    }

    @Test("the profile pairs a bare-day row format with a month-bearing period rule")
    func rowAndPeriodFormatsAgree() async throws {
        let profile = try await loadProfile()
        let rule = try #require(profile.documentPeriod)
        // The pairing is the whole point: "dd" carries no month, so the period
        // rule's format MUST carry one or every row silently lands in January.
        // The pattern itself is not re-typed here — `DateResolverTests` loads it
        // from this same profile and asserts its behaviour directly.
        #expect(profile.dateFormat == "dd")
        #expect(!profile.dateFormat.contains("M"))
        #expect(rule.dateFormat.contains("M"))
    }

    @Test("this fixture is not claimed by gnb-cuenta")
    func gnbCuentaDoesNotClaimIt() async throws {
        let pages = try TestFixtures.pages("continental-cuenta-pages")
        let profiles = try await BundledStatementProfileRepository().profiles(ofKind: .bankAccount)
        let matched = try #require(DefaultStatementProfileMatcher().match(pages: pages, among: profiles))
        #expect(matched.id == "continental-cuenta")
    }
}
