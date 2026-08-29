import Testing
import Foundation
@testable import StatementParsing

@Suite("Footer regression")
struct FooterRegressionTests {
    /// Matched case- and diacritic-insensitively: the same footer says "PAGINA"
    /// on GNB/Itaú and "Página" on Continental, and "El Pago Mínimo" vs
    /// "El pago Mínimo". An exact `contains` silently passes on the variants it
    /// doesn't spell, which is the assertion looking like it holds while
    /// checking nothing.
    private static let footerMarkers = [
        "PAGINA", "EL PAGO MINIMO", "ADVERTENCIAS", "SEGUN RESOLUCION", "SIGUE", "FINAL",
    ]

    private static func contains(_ marker: String, in text: String) -> Bool {
        text.range(of: marker, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    private static let fixtureNames = [
        "gnb-extracto-pages",
        "gnb-movimientos-pages",
        "gnb-cuenta-pages",
        "itau-pages",
        "continental-pages",
    ]

    /// Full auto-detect path (kind + profile), not an explicit profile id: the
    /// defect this pins reproduces via detection resolving Itaú to `gnb-extracto`
    /// (identical layout, wrong bank) — using an explicit profile id would hide
    /// that and, before `itau-extracto`/`continental-extracto` exist, fail for
    /// the wrong reason.
    @Test("no transaction's rawDetail contains footer text, for every fixture", arguments: fixtureNames)
    func noFooterTextInRawDetail(fixtureName: String) async throws {
        let pages = try TestFixtures.pages(fixtureName)
        let result = try await DefaultStatementRowParser().parse(pages: pages)

        for transaction in result.transactions {
            for marker in Self.footerMarkers {
                #expect(
                    !Self.contains(marker, in: transaction.rawDetail),
                    "\(fixtureName): rawDetail contains footer marker \"\(marker)\": \(transaction.rawDetail)"
                )
            }
        }
    }
}
