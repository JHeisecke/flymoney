import Testing
import Foundation
@testable import StatementParsing

@Suite("CreditCardRowPolicy")
struct CreditCardPolicyTests {
    private let profile = StatementProfile(
        id: "test-card",
        displayName: "Test Card",
        bankID: "test",
        currencyCode: "PYG",
        timeZoneIdentifier: "America/Asuncion",
        detection: [],
        minimumDetectionScore: 1,
        tableHeaderPatterns: [],
        columns: [],
        dateFormat: "dd/MM/yy",
        groupingSeparator: ".",
        decimalSeparator: ",",
        documentPeriod: nil,
        yTolerance: 3.0,
        rules: .creditCard(CreditCardRules(
            sections: [],
            excludeDetailPatterns: ["^IVA LEY"],
            excludeWhenColumnsPresent: [.taxFlag],
            refundPrefixPatterns: ["^REINTEGRO\\s+"],
            amountOnFollowingRow: [.foreignPurchase]
        ))
    )

    private func policy() -> CreditCardRowPolicy {
        guard case .creditCard(let rules) = profile.rules else { fatalError() }
        return CreditCardRowPolicy(rules: rules)
    }

    private func candidate(rawDetail: String, cells: RowCells) -> TransactionCandidate {
        TransactionCandidate(
            cells: cells,
            operationDate: Date(),
            rawDetail: rawDetail,
            reference: nil,
            amount: StatementAmount(minorUnits: 1000, currencyCode: "PYG"),
            pageIndex: 0
        )
    }

    @Test("amount parses from the amount band with sign")
    func amountParsesFromAmountBand() {
        let cells = RowCells(byColumn: [.amount: "-49.553"], row: TextRow(midY: 0, words: []))
        let amount = policy().amount(from: cells, profile: profile)
        #expect(amount?.minorUnits == -49553)
    }

    @Test("no amount band means no amount")
    func noAmountBandMeansNoAmount() {
        let cells = RowCells(byColumn: [.detail: "FOOTER TEXT"], row: TextRow(midY: 0, words: []))
        #expect(policy().amount(from: cells, profile: profile) == nil)
    }

    @Test("a non-spending section is skipped")
    func nonSpendingSectionSkipped() {
        let cells = RowCells(byColumn: [:], row: TextRow(midY: 0, words: []))
        let verdict = policy().verdict(for: candidate(rawDetail: "SOME PAGO", cells: cells), section: .payment)
        #expect(verdict == .skip)
    }

    @Test("a spending section without exclusions is kept")
    func spendingSectionKept() {
        let cells = RowCells(byColumn: [:], row: TextRow(midY: 0, words: []))
        let verdict = policy().verdict(for: candidate(rawDetail: "COPETROL", cells: cells), section: .purchase)
        #expect(verdict == .keep)
    }

    @Test("nil section (flat layout) is not skipped by the section check")
    func nilSectionIsNotSkipped() {
        let cells = RowCells(byColumn: [:], row: TextRow(midY: 0, words: []))
        let verdict = policy().verdict(for: candidate(rawDetail: "COPETROL", cells: cells), section: nil)
        #expect(verdict == .keep)
    }

    @Test("a populated excludeWhenColumnsPresent column skips the row even with a spending section")
    func excludeWhenColumnPresentSkips() {
        let cells = RowCells(byColumn: [.taxFlag: "10%"], row: TextRow(midY: 0, words: []))
        let verdict = policy().verdict(for: candidate(rawDetail: "SOME PURCHASE", cells: cells), section: .foreignPurchase)
        #expect(verdict == .skip)
    }

    @Test("a matching excludeDetailPatterns entry skips the row")
    func excludeDetailPatternSkips() {
        let cells = RowCells(byColumn: [:], row: TextRow(midY: 0, words: []))
        let verdict = policy().verdict(for: candidate(rawDetail: "IVA LEY 125/91", cells: cells), section: .purchase)
        #expect(verdict == .skip)
    }
}
