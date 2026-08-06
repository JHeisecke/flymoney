import Testing
import Foundation
@testable import StatementParsing

@Suite("gnb-cuenta end-to-end")
struct GNBCuentaTests {
    private func loadProfile() async throws -> StatementProfile {
        try #require(await BundledStatementProfileRepository().profile(id: "gnb-cuenta"))
    }

    private func parse() async throws -> StatementParseResult {
        let pages = try TestFixtures.pages("gnb-cuenta-pages")
        let profile = try await loadProfile()
        return try DefaultStatementRowParser().parse(pages: pages, profile: profile)
    }

    @Test("9 transactions = 7 outgoing transfers + 2 POS purchases, across both pages")
    func totalsAndSplit() async throws {
        let result = try await parse()
        #expect(result.transactions.count == 9)
        #expect(result.issues.isEmpty)

        let transfers = result.transactions.filter { $0.rawDetail.hasPrefix("Transferencia enviada") }
        let pos = result.transactions.filter { $0.rawDetail.hasPrefix("POS ") }
        #expect(transfers.count == 7)
        #expect(pos.count == 2)

        let pageIndices = Set(result.transactions.map(\.pageIndex))
        #expect(pageIndices == [0, 1])
    }

    @Test("outgoing transfers are flagged ambiguous, POS purchases are not")
    func ambiguousFlagging() async throws {
        let result = try await parse()
        #expect(result.transactions.filter { $0.rawDetail.hasPrefix("Transferencia enviada") }.allSatisfy { $0.isAmbiguous })
        #expect(result.transactions.filter { $0.rawDetail.hasPrefix("POS ") }.allSatisfy { !$0.isAmbiguous })
    }

    @Test("incoming transfers, card payments, ATM rows, interest, Saldo Anterior and TRANSPORTE carry-forwards are excluded")
    func nonSpendingRowsExcluded() async throws {
        let result = try await parse()
        #expect(!result.transactions.contains { $0.rawDetail.hasPrefix("Transferencia recibida") })
        #expect(!result.transactions.contains { $0.rawDetail.contains("Pago Tarj") })
        #expect(!result.transactions.contains { $0.rawDetail.hasPrefix("Saldo Anterior") })
        #expect(!result.transactions.contains { $0.rawDetail.hasPrefix("TRANSPORTE") })
    }

    @Test("Saldo Diario is never emitted as an amount, despite being the rightmost number on every row")
    func balanceNeverImported() async throws {
        let pages = try TestFixtures.pages("gnb-cuenta-pages")
        let profile = try await loadProfile()
        let result = try DefaultStatementRowParser().parse(pages: pages, profile: profile)

        var balances: Set<Int> = []
        for page in pages {
            let rows = DefaultStatementRowParser.band(page.words, yTolerance: profile.yTolerance)
            for row in rows {
                let cells = DefaultStatementRowParser.cells(for: row, page: page, columns: profile.columns)
                guard let raw = cells[.balance] else { continue }
                if let value = AmountParser.parseMinorUnits(raw, groupingSeparator: profile.groupingSeparator, decimalSeparator: profile.decimalSeparator, exponent: 0) {
                    balances.insert(value)
                }
            }
        }
        #expect(!balances.isEmpty)

        let amounts = Set(result.transactions.map(\.amount.minorUnits))
        #expect(amounts.isDisjoint(with: balances))
    }

    @Test("a 0,00 in the unused debit/credit column never produces a zero-value transaction")
    func zeroSentinelNeverBecomesATransaction() async throws {
        let result = try await parse()
        #expect(!result.transactions.contains { $0.amount.minorUnits == 0 })
    }

    @Test("year-less dates resolve against the document period")
    func datesResolveAgainstDocumentPeriod() async throws {
        let result = try await parse()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Asuncion"))
        #expect(result.transactions.allSatisfy { calendar.component(.year, from: $0.operationDate) == 2026 })
        #expect(result.transactions.allSatisfy { calendar.component(.month, from: $0.operationDate) == 7 })
    }
}
