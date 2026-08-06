import Foundation
import PDFKit

// Dev tool: bank PDF -> scrubbed TextPage JSON fixture.
//
// Usage:
//   swift scrub.swift <input.pdf> <output.json> <terms.json>
//
// The redaction terms are NOT in this file and are never committed. A deny-list
// scrubber has to contain the very strings it redacts, so embedding them here
// would publish a tidy, labelled inventory of exactly the data the fixtures were
// cleaned of. Terms live beside the source PDFs, outside the repository.
//
// See Tools/README.md for the terms file format.

// MARK: - Terms

/// Redaction rules, loaded from an external file. Required — a missing or
/// unreadable terms file is a hard failure, never a silent pass-through.
/// Emitting unredacted geometry is the one outcome this tool must never have.
struct ScrubTerms: Decodable {
    /// Literal -> replacement. Replacements are padded/truncated to the ORIGINAL
    /// length so word bounds stay coherent with their text.
    let literals: [String: String]
    /// Bare digit runs at least this long are zeroed. Amounts always carry a
    /// grouping separator in these documents, so they are untouched.
    let minimumDigitRunLength: Int

    /// Longest needle first: a deny-list must prefer the most specific match,
    /// and dictionary iteration order is not stable across processes.
    var orderedLiterals: [(needle: String, replacement: String)] {
        literals
            .sorted { ($0.key.count, $1.key) > ($1.key.count, $0.key) }
            .map { (needle: $0.key, replacement: $0.value) }
    }
}

func loadTerms(_ path: String) -> ScrubTerms {
    guard let data = FileManager.default.contents(atPath: path) else {
        FileHandle.standardError.write(Data("""
        scrub: cannot read terms file at \(path)

        Refusing to run: without terms this tool would emit UNREDACTED geometry.
        Terms live beside the source PDFs, outside the repo. See Tools/README.md.

        """.utf8))
        exit(1)
    }
    do {
        return try JSONDecoder().decode(ScrubTerms.self, from: data)
    } catch {
        FileHandle.standardError.write(Data("scrub: malformed terms file: \(error)\n".utf8))
        exit(1)
    }
}

// MARK: - Redaction

func redactLongDigits(_ s: String, minimumLength: Int) -> String? {
    guard s.count >= minimumLength, s.allSatisfy(\.isNumber) else { return nil }
    return String(repeating: "0", count: s.count)
}

func pad(_ replacement: String, to length: Int) -> String {
    if replacement.count == length { return replacement }
    if replacement.count > length { return String(replacement.prefix(length)) }
    return replacement + String(repeating: "X", count: length - replacement.count)
}

func scrub(_ word: String, terms: ScrubTerms, ordered: [(needle: String, replacement: String)]) -> String {
    if let digits = redactLongDigits(word, minimumLength: terms.minimumDigitRunLength) { return digits }
    var out = word
    for (needle, replacement) in ordered {
        guard out.localizedCaseInsensitiveContains(needle) else { continue }
        out = out.replacingOccurrences(
            of: needle,
            with: pad(replacement, to: needle.count),
            options: [.caseInsensitive]
        )
    }
    return out
}

// MARK: - Geometry model (mirrors StatementParsing/Geometry)

func r2(_ v: Double) -> Double { (v * 100).rounded() / 100 }

struct PositionedWord: Codable { let text: String; let minX, maxX, midY: Double }
struct TextPage: Codable { let index: Int; let width, height: Double; let words: [PositionedWord] }

// MARK: - Extraction

guard CommandLine.arguments.count == 4 else {
    FileHandle.standardError.write(Data("usage: swift scrub.swift <input.pdf> <output.json> <terms.json>\n".utf8))
    exit(1)
}
let path = CommandLine.arguments[1]
let outPath = CommandLine.arguments[2]
let terms = loadTerms(CommandLine.arguments[3])
let orderedTerms = terms.orderedLiterals

let baselineTol = 1.5   // glyph line grouping: intrinsic to rendering, NOT bank-specific
let gapTol = 2.5

guard let doc = PDFDocument(url: URL(fileURLWithPath: path)) else {
    FileHandle.standardError.write(Data("scrub: cannot open PDF at \(path)\n".utf8))
    exit(1)
}

struct Ch { let s: Character; let r: CGRect }
var pages: [TextPage] = []

for p in 0..<doc.pageCount {
    guard let page = doc.page(at: p) else { continue }
    let bounds = page.bounds(for: .mediaBox)

    var items: [Ch] = []
    var lastRect: CGRect = .null
    for i in 0..<page.numberOfCharacters {
        guard let sel = page.selection(for: NSRange(location: i, length: 1)),
              let str = sel.string, let c = str.first else { continue }
        if c == "\n" || c == "\r" { continue }
        let r = sel.bounds(for: page)
        if r.isNull || r.isEmpty { continue }
        if r == lastRect { continue }          // trap 2: last glyph of a run repeats
        lastRect = r
        items.append(Ch(s: c, r: r))
    }

    var bands: [[Ch]] = []
    for ch in items.sorted(by: { $0.r.midY > $1.r.midY }) {
        if let ref = bands.last?.first, abs(ref.r.midY - ch.r.midY) <= baselineTol {
            bands[bands.count - 1].append(ch)
        } else {
            bands.append([ch])
        }
    }

    var pageWords: [PositionedWord] = []
    for band in bands {
        let sorted = band.sorted { $0.r.minX < $1.r.minX }
        var cur = ""; var curMin = 0.0; var curMax = 0.0
        func flush() {
            guard !cur.isEmpty else { return }
            pageWords.append(PositionedWord(
                text: scrub(cur, terms: terms, ordered: orderedTerms),
                minX: r2(curMin),
                maxX: r2(curMax),
                midY: r2(Double(sorted[0].r.midY))
            ))
            cur = ""
        }
        for ch in sorted {
            if ch.s == " " || ch.s == "\t" { flush(); continue }
            if cur.isEmpty { cur = String(ch.s); curMin = Double(ch.r.minX); curMax = Double(ch.r.maxX); continue }
            if Double(ch.r.minX) - curMax > gapTol {
                flush()
                cur = String(ch.s); curMin = Double(ch.r.minX); curMax = Double(ch.r.maxX)
            } else {
                cur.append(ch.s); curMax = max(curMax, Double(ch.r.maxX))
            }
        }
        flush()
    }

    pageWords.sort { $0.midY != $1.midY ? $0.midY > $1.midY : $0.minX < $1.minX }
    pages.append(TextPage(index: p, width: r2(Double(bounds.width)), height: r2(Double(bounds.height)), words: pageWords))
}

let enc = JSONEncoder()
enc.outputFormatting = [.prettyPrinted, .sortedKeys]
try enc.encode(pages).write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath) — \(pages.count) pages, \(pages.reduce(0) { $0 + $1.words.count }) words")
