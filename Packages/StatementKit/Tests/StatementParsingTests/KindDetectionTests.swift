import Testing
@testable import StatementParsing

@Suite("StatementKindDetector")
struct KindDetectionTests {
    private let detector = DefaultStatementKindDetector()

    @Test("gnb-extracto resolves to creditCard")
    func extractoIsCreditCard() throws {
        let pages = try TestFixtures.pages("gnb-extracto-pages")
        #expect(detector.detectKind(pages: pages) == .creditCard)
    }

    @Test("gnb-movimientos resolves to creditCard and scores 0 on account signals — the Débitos/Créditos regression")
    func movimientosIsCreditCardNotAccount() throws {
        let pages = try TestFixtures.pages("gnb-movimientos-pages")
        #expect(detector.detectKind(pages: pages) == .creditCard)

        // MovimientosTarjeta_20260727.pdf ends with "Total Créditos: … / Total
        // Débitos: …" in its footer. If those words ever leaked into the
        // .bankAccount signal vocabulary, this card document would score on
        // both kinds and this assertion would catch it.
        let haystack = pages.first?.words.map(\.text).joined(separator: " ") ?? ""
        let accountScore = StatementKindSignals.bankAccount.reduce(into: 0) { count, signal in
            if haystack.range(of: signal, options: [.caseInsensitive, .diacriticInsensitive]) != nil {
                count += 1
            }
        }
        #expect(accountScore == 0)
    }

    @Test("gnb-cuenta resolves to bankAccount")
    func cuentaIsBankAccount() throws {
        let pages = try TestFixtures.pages("gnb-cuenta-pages")
        #expect(detector.detectKind(pages: pages) == .bankAccount)
    }

    @Test("continental-cuenta resolves to bankAccount despite a card word in its promo footer")
    func continentalCuentaIsBankAccount() throws {
        let pages = try TestFixtures.pages("continental-cuenta-pages")
        #expect(detector.detectKind(pages: pages) == .bankAccount)

        // The page ends with "tus tarjetas de crédito!", which scores 1 on the
        // CARD vocabulary. The margin is 2-to-1, not 2-to-0, so this is pinned
        // rather than trusted — a future edit to StatementKindSignals that adds
        // one card signal or drops one account signal would tie it, and a tie
        // sends the user to the manual picker.
        let haystack = pages.first?.words.map(\.text).joined(separator: " ") ?? ""
        func score(_ signals: [String]) -> Int {
            signals.reduce(into: 0) { count, signal in
                if haystack.range(of: signal, options: [.caseInsensitive, .diacriticInsensitive]) != nil {
                    count += 1
                }
            }
        }
        #expect(score(StatementKindSignals.bankAccount) == 2)
        #expect(score(StatementKindSignals.creditCard) == 1)
    }

    @Test("a document with no signals returns nil")
    func noSignalsReturnsNil() {
        let page = TextPage(index: 0, width: 100, height: 100, words: [
            PositionedWord(text: "HELLO", minX: 0, maxX: 10, midY: 50),
        ])
        #expect(detector.detectKind(pages: [page]) == nil)
    }
}
