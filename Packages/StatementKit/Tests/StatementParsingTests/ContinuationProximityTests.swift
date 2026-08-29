import Testing
import Foundation
@testable import StatementParsing

@Suite("Continuation proximity bound")
struct ContinuationProximityTests {
    /// Minimal single-column-band profile: header + `detail` + `amount`, mirroring
    /// just enough of a real layout to drive the continuation branch without
    /// depending on a bundled bank profile.
    private func profile(continuationMaxGap: Double) -> StatementProfile {
        StatementProfile(
            id: "proximity-test",
            displayName: "Proximity test",
            bankID: "test",
            currencyCode: "PYG",
            timeZoneIdentifier: "America/Asuncion",
            detection: [],
            minimumDetectionScore: 0,
            tableHeaderPatterns: ["FEC.OPERACION", "MONTO"],
            columns: [
                ColumnBand(column: .operationDate, start: 0.00, end: 0.14),
                ColumnBand(column: .detail, start: 0.375, end: 0.70),
                ColumnBand(column: .amount, start: 0.85, end: 1.00),
            ],
            dateFormat: "dd/MM/yy",
            groupingSeparator: ".",
            decimalSeparator: ",",
            documentPeriod: nil,
            yTolerance: 3.0,
            continuationMaxGap: continuationMaxGap,
            rules: .creditCard(CreditCardRules(
                sections: [],
                excludeDetailPatterns: [],
                excludeWhenColumnsPresent: [],
                refundPrefixPatterns: [],
                deferredAmount: nil
            ))
        )
    }

    private func page(rowMidY: Double, continuationMidY: Double) -> TextPage {
        let pageWidth = 616.45
        return TextPage(index: 0, width: pageWidth, height: 800, words: [
            PositionedWord(text: "FEC.", minX: 30, maxX: 55, midY: 551.8),
            PositionedWord(text: "OPERACION", minX: 58, maxX: 90, midY: 551.8),
            PositionedWord(text: "MONTO", minX: 524, maxX: 550, midY: 551.8),
            PositionedWord(text: "27/06/26", minX: 34, maxX: 82, midY: rowMidY),
            PositionedWord(text: "PETROBRAS", minX: 233, maxX: 300, midY: rowMidY),
            PositionedWord(text: "142.150", minX: 555, maxX: 584, midY: rowMidY),
            PositionedWord(text: "CONTINUATION", minX: 250, maxX: 320, midY: continuationMidY),
        ])
    }

    @Test("a continuation band 8pt below its row is appended")
    func withinBoundIsAppended() throws {
        let profile = profile(continuationMaxGap: 16.0)
        let page = page(rowMidY: 453.5, continuationMidY: 445.5) // 8pt gap
        let result = try DefaultStatementRowParser().parse(pages: [page], profile: profile)
        #expect(result.transactions.count == 1)
        #expect(result.transactions.first?.rawDetail == "PETROBRAS CONTINUATION")
    }

    @Test("a continuation band 350pt below its row is not appended")
    func beyondBoundIsNotAppended() throws {
        let profile = profile(continuationMaxGap: 16.0)
        let page = page(rowMidY: 453.5, continuationMidY: 103.5) // 350pt gap
        let result = try DefaultStatementRowParser().parse(pages: [page], profile: profile)
        #expect(result.transactions.count == 1)
        #expect(result.transactions.first?.rawDetail == "PETROBRAS")
    }

    /// `.sections([.foreignPurchase])` must not defer on a non-foreign row —
    /// widening the deferred-amount gate to cover Continental (`.anyRowWithoutAmount`)
    /// must not widen what GNB's `.sections` gate fires on.
    @Test("deferred-rule isolation: .sections does not defer on a non-foreign row")
    func sectionsRuleDoesNotDeferOutsideItsSections() throws {
        var profile = profile(continuationMaxGap: 16.0)
        profile = StatementProfile(
            id: profile.id,
            displayName: profile.displayName,
            bankID: profile.bankID,
            currencyCode: profile.currencyCode,
            timeZoneIdentifier: profile.timeZoneIdentifier,
            detection: profile.detection,
            minimumDetectionScore: profile.minimumDetectionScore,
            tableHeaderPatterns: profile.tableHeaderPatterns,
            columns: profile.columns,
            dateFormat: profile.dateFormat,
            groupingSeparator: profile.groupingSeparator,
            decimalSeparator: profile.decimalSeparator,
            documentPeriod: nil,
            yTolerance: profile.yTolerance,
            continuationMaxGap: profile.continuationMaxGap,
            rules: .creditCard(CreditCardRules(
                sections: [SectionRule(pattern: "^COMPRAENELEXTERIOR$", kind: .foreignPurchase)],
                excludeDetailPatterns: [],
                excludeWhenColumnsPresent: [],
                refundPrefixPatterns: [],
                deferredAmount: .sections([.foreignPurchase])
            ))
        )
        let pageWidth = 616.45
        let page = TextPage(index: 0, width: pageWidth, height: 800, words: [
            PositionedWord(text: "FEC.", minX: 30, maxX: 55, midY: 551.8),
            PositionedWord(text: "OPERACION", minX: 58, maxX: 90, midY: 551.8),
            PositionedWord(text: "MONTO", minX: 524, maxX: 550, midY: 551.8),
            // A row with no amount, NOT inside a .foreignPurchase section: must not defer.
            PositionedWord(text: "27/06/26", minX: 34, maxX: 82, midY: 453.5),
            PositionedWord(text: "NO AMOUNT HERE", minX: 233, maxX: 300, midY: 453.5),
        ])
        let result = try DefaultStatementRowParser().parse(pages: [page], profile: profile)
        #expect(result.transactions.isEmpty)
        #expect(result.issues.isEmpty)
    }
}
