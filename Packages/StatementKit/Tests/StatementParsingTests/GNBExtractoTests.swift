import Testing
import Foundation
@testable import StatementParsing

@Suite("gnb-extracto end-to-end")
struct GNBExtractoTests {
    private func parse() async throws -> StatementParseResult {
        let pages = try TestFixtures.pages("gnb-extracto-pages")
        let repository = BundledStatementProfileRepository()
        let profile = try #require(await repository.profile(id: "gnb-extracto"))
        return try DefaultStatementRowParser().parse(pages: pages, profile: profile)
    }

    @Test("36 transactions = 30 purchases + 6 refunds")
    func totalsAndSplit() async throws {
        let result = try await parse()
        #expect(result.transactions.count == 36)
        let refunds = result.transactions.filter(\.isRefund)
        #expect(refunds.count == 6)
        #expect(result.transactions.count - refunds.count == 30)
        #expect(result.issues.isEmpty)
    }

    @Test("PAGOS, IVA and CARGOS rows are excluded")
    func exclusions() async throws {
        let result = try await parse()
        #expect(!result.transactions.contains { $0.sectionKind == .payment })
        #expect(!result.transactions.contains { $0.sectionKind == .fee })
        #expect(!result.transactions.contains { $0.rawDetail.contains("IVA LEY") })
    }

    @Test("section carries from page 1 into page 3 with no repeated header")
    func sectionCarriesAcrossPages() async throws {
        let result = try await parse()
        let foreignTransactions = result.transactions.filter { $0.sectionKind == .foreignPurchase }
        #expect(foreignTransactions.count == 2)
    }

    @Test("foreign (deferred-amount) rows resolve to 122538 and 60625")
    func foreignRowsResolveDeferredAmounts() async throws {
        let result = try await parse()
        let foreignAmounts = Set(result.transactions.filter { $0.sectionKind == .foreignPurchase }.map(\.amount.minorUnits))
        #expect(foreignAmounts == [122_538, 60_625])
    }

    @Test("refunds normalize to the same key as the purchase they offset")
    func refundNormalizationSharesKeyWithPurchase() async throws {
        let result = try await parse()
        let refund = try #require(result.transactions.first { $0.rawDetail.hasPrefix("REINTEGRO COPETROL") })
        #expect(refund.normalizedDetail == "COPETROL")
        #expect(!refund.normalizedDetail.contains("REINTEGRO"))
    }

    @Test("distinct merchants with similar names stay distinct — no guessed grouping")
    func distinctMerchantsStayDistinct() async throws {
        let result = try await parse()
        let normalized = Set(result.transactions.map(\.normalizedDetail))
        #expect(normalized.contains("S6- MBURUKUYA SCO"))
        #expect(normalized.contains("S6- LAURELES SCO"))
        #expect(normalized.contains("FCIA PUNTO FARMA-P383"))
        #expect(normalized.contains("FCIA PUNTO FARMA-P 697"))
    }

    @Test("all currencies are PYG, exponent 0, minorUnits carries no fractional digits")
    func currencyIsConsistent() async throws {
        let result = try await parse()
        #expect(result.transactions.allSatisfy { $0.amount.currencyCode == "PYG" })
    }
}
