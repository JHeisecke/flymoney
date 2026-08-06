import Testing
import Foundation
@testable import StatementParsing

@Suite("BankAccountRowPolicy")
struct BankAccountPolicyTests {
    private let profile = StatementProfile(
        id: "test-account",
        displayName: "Test Account",
        bankID: "test",
        currencyCode: "PYG",
        timeZoneIdentifier: "America/Asuncion",
        detection: [],
        minimumDetectionScore: 1,
        tableHeaderPatterns: [],
        columns: [],
        dateFormat: "d/M",
        groupingSeparator: ".",
        decimalSeparator: ",",
        documentPeriod: nil,
        yTolerance: 6.0,
        rules: .bankAccount(BankAccountRules(
            includeDetailPatterns: ["^POS ", "^Transferencia enviada"],
            ambiguousDetailPatterns: ["^Transferencia enviada"]
        ))
    )

    private func policy() -> BankAccountRowPolicy {
        guard case .bankAccount(let rules) = profile.rules else { fatalError() }
        return BankAccountRowPolicy(rules: rules)
    }

    private func candidate(rawDetail: String) -> TransactionCandidate {
        TransactionCandidate(
            cells: RowCells(byColumn: [:], row: TextRow(midY: 0, words: [])),
            operationDate: Date(),
            rawDetail: rawDetail,
            reference: nil,
            amount: StatementAmount(minorUnits: 1000, currencyCode: "PYG"),
            pageIndex: 0
        )
    }

    @Test("debit column value, non-zero, becomes the amount unnegated")
    func debitNonZeroWins() {
        let cells = RowCells(byColumn: [.debit: "674.609", .credit: "0,00"], row: TextRow(midY: 0, words: []))
        let amount = policy().amount(from: cells, profile: profile)
        #expect(amount?.minorUnits == 674_609)
    }

    @Test("credit column value, non-zero, becomes the amount negated")
    func creditNonZeroIsNegated() {
        let cells = RowCells(byColumn: [.debit: "0,00", .credit: "4.500.000"], row: TextRow(midY: 0, words: []))
        let amount = policy().amount(from: cells, profile: profile)
        #expect(amount?.minorUnits == -4_500_000)
    }

    @Test("both zero means not a transaction")
    func bothZeroMeansNoTransaction() {
        let cells = RowCells(byColumn: [.debit: "0,00", .credit: "0,00"], row: TextRow(midY: 0, words: []))
        #expect(policy().amount(from: cells, profile: profile) == nil)
    }

    @Test("balance is never read as an amount")
    func balanceNeverBecomesAmount() {
        let cells = RowCells(byColumn: [.balance: "4.556.000"], row: TextRow(midY: 0, words: []))
        #expect(policy().amount(from: cells, profile: profile) == nil)
    }

    @Test("only matching includeDetailPatterns rows are kept — everything else is dropped")
    func onlyIncludedPatternsKept() {
        #expect(policy().verdict(for: candidate(rawDetail: "POS TD CASA RICA"), section: nil) == .keep)
        #expect(policy().verdict(for: candidate(rawDetail: "Transferencia recibida SPI"), section: nil) == .skip)
        #expect(policy().verdict(for: candidate(rawDetail: "Extracción cajero automático"), section: nil) == .skip)
    }

    @Test("outgoing transfers match include AND ambiguous — keepFlaggedAmbiguous")
    func outgoingTransferIsAmbiguous() {
        #expect(policy().verdict(for: candidate(rawDetail: "Transferencia enviada SPI"), section: nil) == .keepFlaggedAmbiguous)
    }

    @Test("POS purchases match include but not ambiguous — plain keep")
    func posPurchaseIsNotAmbiguous() {
        #expect(policy().verdict(for: candidate(rawDetail: "POS TD MT-SN"), section: nil) == .keep)
    }
}
