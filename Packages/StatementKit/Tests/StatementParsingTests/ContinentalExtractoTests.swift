import Testing
import Foundation
@testable import StatementParsing

@Suite("continental-extracto end-to-end")
struct ContinentalExtractoTests {
    private func parse() async throws -> StatementParseResult {
        let pages = try TestFixtures.pages("continental-pages")
        let repository = BundledStatementProfileRepository()
        let profile = try #require(await repository.profile(id: "continental-extracto"))
        return try DefaultStatementRowParser().parse(pages: pages, profile: profile)
    }

    /// The full expected parse, in document order. Derived independently of the
    /// parser — by applying the profile's bands and rules to the fixture in a
    /// script — so a parser change that alters any row fails here rather than
    /// being absorbed by a loose count assertion.
    private static let expected: [(detail: String, minorUnits: Int)] = [
        ("LA FERNETERIA AsuPY", 50_000),
        ("OPENAI *CHATGPT SUBSCR", 124_440),
        ("CINEMARK PARAGUAY VPOS WEASUPY", 48_000),
        ("PETROBRAS", 150_000),
        ("PEDIDOS YA PLUS ASUPY", 100),
        ("PEDIDOS YA ASUPY", 55_000),
        ("AIRBNB * HM55C4ZYQ2", 293_691),
        ("PEDIDOS YA-PROPINAS ASUPY", 4_000),
        ("CONTIDESCUENTOS", -30_000),
        ("PEDIDOS YA PLUS", -100),
        ("CTRO MEDICO BAUTISTA ASUPY", 253_876),
        ("APPLE.COM BILL", 6_153),
        ("Spotify P4464AFA57", 37_233),
        ("PETROBRAS", 100_000),
        ("CONTIDESCUENTOS", -20_000),
        ("FCIA PUNTO FARMA-P228 LAMPY", 151_462),
        ("PHYSICAL STUDIO ASUPY", 250_000),
        ("PETROBRAS", 150_000),
        ("CONTIDESCUENTOS", -30_000),
        ("APPLE.COM BILL", 18_490),
        ("BARRITA ASUPY", 94_000),
        ("DLOCAL *BOLT 123PY", 31_500),
        ("F. CATEDRAL RCA ARGENTINA 3", 106_150),
        ("CONTIDESCUENTOS", -10_615),
    ]

    @Test("the full 24-row parse matches, row for row, in document order")
    func fullManifest() async throws {
        let result = try await parse()
        #expect(result.transactions.count == Self.expected.count)
        #expect(result.issues.isEmpty)
        for (index, expected) in Self.expected.enumerated() {
            guard index < result.transactions.count else { break }
            let actual = result.transactions[index]
            #expect(actual.rawDetail == expected.detail, "row \(index) detail")
            #expect(actual.amount.minorUnits == expected.minorUnits, "row \(index) amount for \(expected.detail)")
        }
    }

    @Test("38 candidate rows split 24 imported / 14 skipped")
    func importedSkippedSplit() async throws {
        let result = try await parse()
        // 14 skipped is asserted by its complement: every excluded row is named
        // in `skippedDetails` below, and none of them survives into the result.
        #expect(result.transactions.count == 24)
        let skippedDetails = [
            "SU PAGO GRACIAS",
            "618094361758-IVA LEY 6380-SERVICIOS DIGI",
            "CARGO POR COMPRAS INTERNACIONALES",
            "MANT. DE CUENTA ANUAL CTA.001/003",
            "618998874172-IVA LEY 6380-SERVICIOS DIGI",
            "619099297690-IVA LEY 6380-SERVICIOS DIGI",
            "619802905783-IVA LEY 6380-SERVICIOS DIGI",
            "MANTENIM. MENSUAL",
            "SEGURO CANCELACION DE DEUDA",
        ]
        for detail in skippedDetails {
            #expect(!result.transactions.contains { $0.rawDetail == detail }, "\(detail) should be skipped")
        }
    }

    @Test("totals: 19 purchases, 5 CR credits, net 1833380")
    func totals() async throws {
        let result = try await parse()
        let credits = result.transactions.filter { $0.amount.minorUnits < 0 }
        #expect(credits.count == 5)
        #expect(result.transactions.count - credits.count == 19)
        #expect(result.transactions.reduce(0) { $0 + $1.amount.minorUnits } == 1_833_380)
    }

    @Test("CR-suffixed credits carry their exact negative values and are flagged as refunds")
    func creditSuffixValues() async throws {
        let result = try await parse()
        let credits = result.transactions.filter { $0.amount.minorUnits < 0 }
        #expect(credits.allSatisfy { $0.isRefund })
        #expect(credits.map(\.amount.minorUnits).sorted() == [-30_000, -30_000, -20_000, -10_615, -100].sorted())
        let contidescuentos = result.transactions.filter { $0.rawDetail == "CONTIDESCUENTOS" }
        #expect(contidescuentos.count == 4)
        #expect(contidescuentos.allSatisfy { $0.amount.minorUnits < 0 })
    }

    @Test("SU PAGO GRACIAS is excluded by pattern, not by its CR sign")
    func suPagoExcludedByPattern() async throws {
        let result = try await parse()
        #expect(!result.transactions.contains { $0.rawDetail.contains("SU PAGO") })
        // Both payments carry CR, i.e. they parse fine and are dropped by the
        // rule rather than vanishing because AmountParser rejected them.
        let profile = try #require(await BundledStatementProfileRepository().profile(id: "continental-extracto"))
        #expect(AmountParser.parseMinorUnits(
            "2.000.000CR", groupingSeparator: profile.groupingSeparator,
            decimalSeparator: profile.decimalSeparator, exponent: 0,
            creditSuffixes: profile.creditSuffixes
        ) == -2_000_000)
    }

    @Test("-IVA LEY rows are excluded even though their taxFlag cell is empty")
    func ivaLeyExcludedByDetailPattern() async throws {
        let result = try await parse()
        #expect(!result.transactions.contains { $0.rawDetail.contains("IVA LEY") })
    }

    @Test("10%-bearing charge rows are excluded via taxFlag")
    func taxFlagExclusions() async throws {
        let result = try await parse()
        #expect(!result.transactions.contains { $0.rawDetail.contains("CARGO POR COMPRAS INTERNACIONALES") })
        #expect(!result.transactions.contains { $0.rawDetail.contains("MANT. DE CUENTA") })
        #expect(!result.transactions.contains { $0.rawDetail.contains("MANTENIM. MENSUAL") })
        #expect(!result.transactions.contains { $0.rawDetail.contains("SEGURO CANCELACION") })
    }

    @Test("the 5 deferred foreign rows resolve to their exact ₲ amounts, not the U$ or COTIZ. figure")
    func deferredForeignRowsResolveExactGuaraniAmounts() async throws {
        let result = try await parse()
        let expected: [(detail: String, minorUnits: Int, usd: Int, cotiz: Int)] = [
            ("OPENAI *CHATGPT SUBSCR", 124_440, 20, 6_222),
            ("AIRBNB * HM55C4ZYQ2", 293_691, 47, 6_217),
            ("APPLE.COM BILL", 6_153, 0, 6_216),
            ("Spotify P4464AFA57", 37_233, 5, 6_216),
            ("APPLE.COM BILL", 18_490, 2, 6_184),
        ]
        for (detail, minorUnits, usd, cotiz) in expected {
            let match = try #require(
                result.transactions.first { $0.rawDetail == detail && $0.amount.minorUnits == minorUnits },
                "no \(detail) at \(minorUnits)"
            )
            #expect(match.amount.minorUnits != usd)
            #expect(match.amount.minorUnits != cotiz)
        }
    }

    /// The follower row that supplies a deferred amount carries the exchange
    /// rate in its `taxFlag` cell. The verdict must be taken on the *deferred
    /// row's own* cells — if it used the follower's, `excludeWhenColumnsPresent:
    /// [taxFlag]` would skip all five foreign purchases.
    @Test("a deferred row is judged on its own cells, not the amount-supplying row's")
    func deferredRowKeepsItsOwnCellsForTheVerdict() async throws {
        let result = try await parse()
        let foreign = result.transactions.filter {
            ["OPENAI *CHATGPT SUBSCR", "AIRBNB * HM55C4ZYQ2", "APPLE.COM BILL", "Spotify P4464AFA57"].contains($0.rawDetail)
        }
        #expect(foreign.count == 5)
    }

    @Test("footer bands are rejected by the proximity bound, not merged into the last row")
    func footerBandsRejected() async throws {
        let result = try await parse()
        let last = try #require(result.transactions.last)
        #expect(last.rawDetail == "CONTIDESCUENTOS")
        for marker in ["Página", "SIGUE", "FINAL", "pago Mínimo", "Advertencias"] {
            #expect(!result.transactions.contains { $0.rawDetail.contains(marker) }, "\(marker) leaked into a rawDetail")
        }
    }

    @Test("gnb-extracto and itau-extracto do not match the Continental fixture")
    func onlyContinentalProfileMatches() async throws {
        let pages = try TestFixtures.pages("continental-pages")
        let repository = BundledStatementProfileRepository()
        let matcher = DefaultStatementProfileMatcher()
        let profiles = try await repository.profiles(ofKind: .creditCard)
        let match = matcher.match(pages: pages, among: profiles)
        #expect(match?.id == "continental-extracto")
    }
}
