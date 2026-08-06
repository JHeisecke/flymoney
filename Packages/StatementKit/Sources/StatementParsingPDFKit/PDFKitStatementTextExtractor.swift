import Foundation
import PDFKit
import StatementParsing

/// The only file in the package that imports PDFKit. Reconstructs `[TextPage]`
/// from character geometry — `PDFPage.string` reading order is unusable (see
/// Stage 15 plan §1): it can emit each table column as its own text stream.
public struct PDFKitStatementTextExtractor: StatementTextExtracting {
    /// Baseline tolerance for grouping glyphs sharing a visual line. Intrinsic
    /// to PDF text rendering, not bank-specific — never a parameter.
    private static let baselineTolerance: Double = 1.5

    public init() {}

    public func extract(fileURL: URL, gapTolerance: Double = 2.5) async throws -> [TextPage] {
        guard let document = PDFDocument(url: fileURL) else {
            throw StatementParseError.unreadableDocument
        }

        var pages: [TextPage] = []
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            pages.append(extractPage(page, index: pageIndex, gapTolerance: gapTolerance))
        }
        return pages
    }

    private struct Glyph {
        let character: Character
        let bounds: CGRect
    }

    private func extractPage(_ page: PDFPage, index: Int, gapTolerance: Double) -> TextPage {
        let mediaBounds = page.bounds(for: .mediaBox)

        var glyphs: [Glyph] = []
        var lastBounds: CGRect = .null
        for i in 0..<page.numberOfCharacters {
            // Trap 1: `page.characterBounds(at:)` is NOT index-aligned with
            // `page.string` — it welds correct bounds to the wrong characters.
            // `selection(for:)` keeps string and bounds from the same selection.
            guard let selection = page.selection(for: NSRange(location: i, length: 1)),
                  let string = selection.string,
                  let character = string.first
            else { continue }
            if character == "\n" || character == "\r" { continue }

            let bounds = selection.bounds(for: page)
            if bounds.isNull || bounds.isEmpty { continue }

            // Trap 2: the last glyph of every text run is returned twice with
            // identical bounds. Drop the repeat or every amount silently gains
            // a trailing digit ("345.000" -> "345.0000").
            if bounds == lastBounds { continue }
            lastBounds = bounds

            glyphs.append(Glyph(character: character, bounds: bounds))
        }

        let lines = groupIntoBaselines(glyphs)
        var words: [PositionedWord] = []
        for line in lines {
            words.append(contentsOf: splitIntoWords(line, gapTolerance: gapTolerance))
        }

        words.sort {
            $0.midY != $1.midY ? $0.midY > $1.midY : $0.minX < $1.minX
        }

        return TextPage(
            index: index,
            width: round2(Double(mediaBounds.width)),
            height: round2(Double(mediaBounds.height)),
            words: words
        )
    }

    private func groupIntoBaselines(_ glyphs: [Glyph]) -> [[Glyph]] {
        var lines: [[Glyph]] = []
        for glyph in glyphs.sorted(by: { $0.bounds.midY > $1.bounds.midY }) {
            if let reference = lines.last?.first,
               abs(Double(reference.bounds.midY - glyph.bounds.midY)) <= Self.baselineTolerance {
                lines[lines.count - 1].append(glyph)
            } else {
                lines.append([glyph])
            }
        }
        return lines
    }

    private func splitIntoWords(_ line: [Glyph], gapTolerance: Double) -> [PositionedWord] {
        let sorted = line.sorted { $0.bounds.minX < $1.bounds.minX }
        guard let lineMidY = sorted.first.map({ Double($0.bounds.midY) }) else { return [] }

        var result: [PositionedWord] = []
        var current = ""
        var currentMinX = 0.0
        var currentMaxX = 0.0

        func flush() {
            guard !current.isEmpty else { return }
            result.append(PositionedWord(
                text: current,
                minX: round2(currentMinX),
                maxX: round2(currentMaxX),
                midY: round2(lineMidY)
            ))
            current = ""
        }

        for glyph in sorted {
            if glyph.character == " " || glyph.character == "\t" {
                flush()
                continue
            }
            if current.isEmpty {
                current = String(glyph.character)
                currentMinX = Double(glyph.bounds.minX)
                currentMaxX = Double(glyph.bounds.maxX)
            } else if Double(glyph.bounds.minX) - currentMaxX > gapTolerance {
                flush()
                current = String(glyph.character)
                currentMinX = Double(glyph.bounds.minX)
                currentMaxX = Double(glyph.bounds.maxX)
            } else {
                current.append(glyph.character)
                currentMaxX = max(currentMaxX, Double(glyph.bounds.maxX))
            }
        }
        flush()

        return result
    }

    private func round2(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }
}
