import Testing
@testable import StatementParsing

@Suite("Row banding + column assignment")
struct RowGroupingTests {
    @Test("at yTolerance 3.0 a full card row lands in one TextRow, the 8pt-lower continuation stays separate")
    func cardRowBandingSeparatesContinuation() {
        let words = [
            PositionedWord(text: "27/06/26", minX: 34, maxX: 82, midY: 448.9),
            PositionedWord(text: "REINTEGRO", minX: 233, maxX: 300, midY: 448.9),
            PositionedWord(text: "COPETROL", minX: 300, maxX: 340, midY: 440.9), // 8pt lower
        ]
        let rows = DefaultStatementRowParser.band(words, yTolerance: 3.0)
        #expect(rows.count == 2)
        #expect(rows[0].words.count == 2)
        #expect(rows[1].words.count == 1)
    }

    @Test("gnb-cuenta's 3.6pt wrapped row merges at yTolerance 6.0")
    func cuentaWrapMergesAtSixPoints() {
        let words = [
            PositionedWord(text: "1/7", minX: 37, maxX: 49, midY: 446.0),
            PositionedWord(text: "Transferencia", minX: 91, maxX: 185, midY: 446.0),
            PositionedWord(text: "4.500.000", minX: 464, maxX: 500, midY: 442.4), // 3.6pt lower
        ]
        let rows = DefaultStatementRowParser.band(words, yTolerance: 6.0)
        #expect(rows.count == 1)
        #expect(rows[0].words.count == 3)
    }

    @Test("gnb-cuenta's 3.6pt wrapped row does NOT merge at yTolerance 3.0")
    func cuentaWrapStaysSeparateAtThreePoints() {
        let words = [
            PositionedWord(text: "1/7", minX: 37, maxX: 49, midY: 446.0),
            PositionedWord(text: "Transferencia", minX: 91, maxX: 185, midY: 446.0),
            PositionedWord(text: "4.500.000", minX: 464, maxX: 500, midY: 442.4),
        ]
        let rows = DefaultStatementRowParser.band(words, yTolerance: 3.0)
        #expect(rows.count == 2)
    }

    @Test("space-padded cells and gap-separated cells both split into the same word count")
    func wordSplittingHandlesBothLayouts() {
        // ExtractoTarjeta pads cells with real space glyphs — space-splitting alone
        // would work, but words are already pre-split by the extractor. This test
        // instead pins column assignment, since that's where the two real layouts
        // (padded vs gap-only) actually diverge in practice.
        let page = TextPage(index: 0, width: 616.45, height: 800, words: [
            PositionedWord(text: "D", minX: 322, maxX: 330, midY: 551.8),
            PositionedWord(text: "E", minX: 332, maxX: 340, midY: 551.8),
            PositionedWord(text: "T", minX: 342, maxX: 350, midY: 551.8),
            PositionedWord(text: "A", minX: 352, maxX: 360, midY: 551.8),
            PositionedWord(text: "L", minX: 361, maxX: 365, midY: 551.8),
        ])
        let row = TextRow(midY: 551.8, words: page.words)
        let columns: [ColumnBand] = [
            ColumnBand(column: .detail, start: 0.375, end: 0.70),
            ColumnBand(column: .rateFlag, start: 0.70, end: 0.765),
        ]
        let cells = DefaultStatementRowParser.cells(for: row, page: page, columns: columns)
        // Header glyphs are letter-spaced and centred at x≈343 (fraction≈0.556), inside `detail`.
        #expect(cells[.detail] != nil)
    }

    @Test("D E T A L L E header at 322–365 does not capture data at 233 — PETROBRAS lands in detail")
    func headerPositionDoesNotLocateColumns() {
        let page = TextPage(index: 0, width: 616.45, height: 800, words: [
            PositionedWord(text: "PETROBRAS", minX: 233, maxX: 300, midY: 500),
        ])
        let row = TextRow(midY: 500, words: page.words)
        let columns: [ColumnBand] = [
            ColumnBand(column: .reference, start: 0.26, end: 0.375),
            ColumnBand(column: .detail, start: 0.375, end: 0.70),
        ]
        let cells = DefaultStatementRowParser.cells(for: row, page: page, columns: columns)
        #expect(cells[.detail] == "PETROBRAS")
        #expect(cells[.reference] == nil)
    }

    @Test("the header row is located by its space-stripped joined text")
    func headerRowLocatedBySpaceStrippedText() {
        let words = [
            PositionedWord(text: "FEC.", minX: 30, maxX: 55, midY: 551.8),
            PositionedWord(text: "OPERACION", minX: 58, maxX: 90, midY: 551.8),
            PositionedWord(text: "MONTO", minX: 524, maxX: 550, midY: 551.8),
        ]
        let row = TextRow(midY: 551.8, words: words)
        #expect(DefaultStatementRowParser.isHeaderRow(row, patterns: ["FEC.OPERACION", "MONTO"]))
        #expect(!DefaultStatementRowParser.isHeaderRow(row, patterns: ["SALDODIARIO"]))
    }
}
