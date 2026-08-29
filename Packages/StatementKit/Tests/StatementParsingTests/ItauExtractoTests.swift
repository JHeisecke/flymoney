import Testing
import Foundation
@testable import StatementParsing

@Suite("itau-extracto end-to-end")
struct ItauExtractoTests {
    private func parse() async throws -> StatementParseResult {
        let pages = try TestFixtures.pages("itau-pages")
        let repository = BundledStatementProfileRepository()
        let profile = try #require(await repository.profile(id: "itau-extracto"))
        return try DefaultStatementRowParser().parse(pages: pages, profile: profile)
    }

    /// Derived independently of the parser, by applying the profile's bands and
    /// rules to the fixture in a script.
    private static let expected: [(detail: String, minorUnits: Int)] = [
        ("FCIA.PUNTO FARMA-P212", 58_800),
        ("BIGGIE-MBURUCUYA", 73_150),
        ("12 LEÑAS", 135_000),
        ("MT-SN", 52_000),
        ("SELTZ", 29_000),
        ("SUP.S6-MBURUCUYA", 142_150),
    ]

    @Test("6 transactions, no issues")
    func totalCount() async throws {
        let result = try await parse()
        #expect(result.transactions.count == 6)
        #expect(result.issues.isEmpty)
    }

    @Test("the full 6-row parse matches, row for row, in document order")
    func fullManifest() async throws {
        let result = try await parse()
        #expect(result.transactions.count == Self.expected.count)
        for (index, expected) in Self.expected.enumerated() {
            guard index < result.transactions.count else { break }
            let actual = result.transactions[index]
            #expect(actual.rawDetail == expected.detail, "row \(index) detail")
            #expect(actual.amount.minorUnits == expected.minorUnits, "row \(index) amount for \(expected.detail)")
        }
    }

    @Test("all amounts positive — this statement carries no credits")
    func noCredits() async throws {
        let result = try await parse()
        #expect(result.transactions.allSatisfy { $0.amount.minorUnits > 0 })
        #expect(!result.transactions.contains { $0.isRefund })
    }

    /// The three footer bands that the unbounded continuation rule appended to
    /// `SUP.S6-MBURUCUYA` — the defect Stage 19 exists to fix. They sit ~350pt,
    /// ~400pt and ~430pt below the row, well past the 16pt bound.
    @Test("the three Itaú footer bands are all rejected")
    func footerBandsRejected() async throws {
        let result = try await parse()
        for marker in ["tarjeta y cada mes", "El Pago Mínimo", "PAGINA", "FINAL"] {
            #expect(!result.transactions.contains { $0.rawDetail.contains(marker) }, "\(marker) leaked")
        }
    }

    @Test("last transaction is exactly SUP.S6-MBURUCUYA at 142150 — no footer text appended")
    func lastTransactionIsClean() async throws {
        let result = try await parse()
        let last = try #require(result.transactions.last)
        #expect(last.rawDetail == "SUP.S6-MBURUCUYA")
        #expect(last.amount.minorUnits == 142_150)
    }

    @Test("Seg.de canc.Deuda is excluded via taxFlag")
    func taxFlagExclusion() async throws {
        let result = try await parse()
        #expect(!result.transactions.contains { $0.rawDetail.contains("Seg.de canc.Deuda") })
    }

    @Test("gnb-extracto does not match the Itaú fixture")
    func gnbProfileDoesNotMatchItau() async throws {
        let pages = try TestFixtures.pages("itau-pages")
        let repository = BundledStatementProfileRepository()
        let matcher = DefaultStatementProfileMatcher()
        let profiles = try await repository.profiles(ofKind: .creditCard)
        let match = matcher.match(pages: pages, among: profiles)
        #expect(match?.id == "itau-extracto")
    }
}
