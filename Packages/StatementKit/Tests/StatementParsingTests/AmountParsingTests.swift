import Testing
@testable import StatementParsing

@Suite("AmountParser")
struct AmountParsingTests {
    private let pygExponent = CurrencyExponent.digits(for: "PYG", override: nil)

    @Test("PYG exponent is 0")
    func pygExponentIsZero() {
        #expect(pygExponent == 0)
    }

    @Test("override wins over ICU")
    func overrideWinsOverICU() {
        #expect(CurrencyExponent.digits(for: "PYG", override: 2) == 2)
    }

    @Test("plain grouped amount parses positive")
    func plainAmount() {
        let value = AmountParser.parseMinorUnits("345.000", groupingSeparator: ".", decimalSeparator: ",", exponent: pygExponent)
        #expect(value == 345_000)
    }

    @Test("leading minus parses negative")
    func negativeLeadingMinus() {
        let value = AmountParser.parseMinorUnits("-49.553", groupingSeparator: ".", decimalSeparator: ",", exponent: pygExponent)
        #expect(value == -49553)
    }

    @Test("multi-group amount with sign")
    func multiGroupWithSign() {
        let value = AmountParser.parseMinorUnits("-1.597.237", groupingSeparator: ".", decimalSeparator: ",", exponent: pygExponent)
        #expect(value == -1_597_237)
    }

    @Test("a decimal fraction on a zero-exponent currency is rejected unless it's the 0,00 sentinel")
    func decimalFractionRejectedOnZeroExponent() {
        let value = AmountParser.parseMinorUnits("6.130,00", groupingSeparator: ".", decimalSeparator: ",", exponent: pygExponent)
        #expect(value == nil)
    }

    @Test("0,00 parses to zero — never rejected, never a stray digit")
    func zeroSentinelParses() {
        let value = AmountParser.parseMinorUnits("0,00", groupingSeparator: ".", decimalSeparator: ",", exponent: pygExponent)
        #expect(value == 0)
    }

    @Test("debit column value parses positive")
    func debitColumnValue() {
        let value = AmountParser.parseMinorUnits("674.609", groupingSeparator: ".", decimalSeparator: ",", exponent: pygExponent)
        #expect(value == 674_609)
    }

    @Test("stray characters are rejected, not coerced")
    func strayCharacterRejected() {
        let value = AmountParser.parseMinorUnits("₲345.000", groupingSeparator: ".", decimalSeparator: ",", exponent: pygExponent)
        #expect(value == nil)
    }

    @Test("empty string is rejected")
    func emptyRejected() {
        let value = AmountParser.parseMinorUnits("", groupingSeparator: ".", decimalSeparator: ",", exponent: pygExponent)
        #expect(value == nil)
    }
}
