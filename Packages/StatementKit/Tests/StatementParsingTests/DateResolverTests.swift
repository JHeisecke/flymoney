import Testing
import Foundation
@testable import StatementParsing

@Suite("DateResolver")
struct DateResolverTests {
    private let timeZoneID = "America/Asuncion"

    @Test("a dateFormat carrying its own year needs no document period")
    func fullYearDate() throws {
        let date = DateResolver.resolveDate(
            "27/07/26",
            dateFormat: "dd/MM/yy",
            timeZoneIdentifier: timeZoneID,
            documentPeriod: nil
        )
        let date2 = try #require(date)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: timeZoneID))
        let comps = calendar.dateComponents([.year, .month, .day], from: date2)
        #expect(comps.year == 2026)
        #expect(comps.month == 7)
        #expect(comps.day == 27)
    }

    @Test("document period extraction resolves the year from Desde")
    func documentPeriodExtraction() throws {
        let rule = DocumentPeriodRule(pattern: "Desde\\s+(\\d{2}/\\d{2}/\\d{2})", dateFormat: "dd/MM/yy")
        let period = DateResolver.extractDocumentPeriod(
            fullText: "Movimientos de Cuenta Desde 01/07/26 Hasta 31/07/26",
            rule: rule,
            timeZoneIdentifier: timeZoneID
        )
        #expect(period?.year == 2026)
    }

    @Test("a year-less date resolves against the document period")
    func yearLessDateResolvesAgainstPeriod() throws {
        let date = DateResolver.resolveDate(
            "14/7",
            dateFormat: "d/M",
            timeZoneIdentifier: timeZoneID,
            documentPeriod: DocumentPeriod(year: 2026)
        )
        let date2 = try #require(date)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: timeZoneID))
        let comps = calendar.dateComponents([.year, .month, .day], from: date2)
        #expect(comps.year == 2026)
        #expect(comps.month == 7)
        #expect(comps.day == 14)
    }

    @Test("a year-less date with no document period fails rather than defaulting")
    func yearLessDateWithNoPeriodFails() {
        let date = DateResolver.resolveDate(
            "14/7",
            dateFormat: "d/M",
            timeZoneIdentifier: timeZoneID,
            documentPeriod: nil
        )
        #expect(date == nil)
    }

    @Test("a declared but unmatched document period rule returns nil, not the current year")
    func unmatchedDocumentPeriodRuleReturnsNil() {
        let rule = DocumentPeriodRule(pattern: "Desde\\s+(\\d{2}/\\d{2}/\\d{2})", dateFormat: "dd/MM/yy")
        let period = DateResolver.extractDocumentPeriod(
            fullText: "No period header on this page",
            rule: rule,
            timeZoneIdentifier: timeZoneID
        )
        #expect(period == nil)
    }
}
