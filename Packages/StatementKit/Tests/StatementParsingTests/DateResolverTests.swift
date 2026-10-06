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

    // MARK: - Bare day-of-month rows (Stage 21)

    @Test("a year-only period rule carries no month")
    func yearOnlyRuleHasNoMonth() {
        // `gnb-cuenta`'s rule. "yyyy" parses to January 1st, so a nil month here
        // has to come from inspecting the format, not the parsed value.
        let rule = DocumentPeriodRule(pattern: "Mes:\\s+\\S+/(\\d{4})", dateFormat: "yyyy")
        let period = DateResolver.extractDocumentPeriod(
            fullText: "Mes: JULIO/2026",
            rule: rule,
            timeZoneIdentifier: timeZoneID
        )
        #expect(period?.year == 2026)
        #expect(period?.month == nil)
    }

    @Test("a period rule carrying a month yields one")
    func monthBearingRuleHasMonth() async throws {
        let period = DateResolver.extractDocumentPeriod(
            fullText: "Desde el 01/08/2026 hasta el 31/08/2026",
            rule: try await continentalCuentaPeriodRule(),
            timeZoneIdentifier: timeZoneID
        )
        #expect(period?.year == 2026)
        #expect(period?.month == 8)
    }

    @Test("a bare day-of-month resolves against the period's month, not the formatter's January")
    func bareDayResolvesAgainstPeriodMonth() throws {
        let date = try #require(DateResolver.resolveDate(
            "03",
            dateFormat: "dd",
            timeZoneIdentifier: timeZoneID,
            documentPeriod: DocumentPeriod(year: 2026, month: 8)
        ))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: timeZoneID))
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        #expect(comps.year == 2026)
        #expect(comps.month == 8)
        #expect(comps.day == 3)
    }

    @Test("a bare day-of-month with a month-less period fails rather than landing in January")
    func bareDayWithNoPeriodMonthFails() {
        // The whole point of the guard: `DateFormatter` parses "03" to
        // 2000-01-03, so accepting the parsed month would file every row of an
        // August statement under January without any symptom.
        #expect(DateResolver.resolveDate(
            "03",
            dateFormat: "dd",
            timeZoneIdentifier: timeZoneID,
            documentPeriod: DocumentPeriod(year: 2026)
        ) == nil)
    }

    @Test("a period spanning two months does not resolve at all")
    func crossMonthPeriodDoesNotResolve() async throws {
        // The `\\1` backreference in the profile's pattern. With a bare-day row
        // column a two-month window is genuinely ambiguous, so the honest
        // outcome is `.missingDocumentPeriod`, not half a statement misdated.
        let rule = try await continentalCuentaPeriodRule()
        #expect(DateResolver.extractDocumentPeriod(
            fullText: "Desde el 15/07/2026 hasta el 14/08/2026",
            rule: rule,
            timeZoneIdentifier: timeZoneID
        ) == nil)
        // Same-month ranges must still resolve — otherwise this assertion would
        // pass just as well against a pattern that matches nothing at all.
        #expect(DateResolver.extractDocumentPeriod(
            fullText: "Desde el 01/08/2026 hasta el 31/08/2026",
            rule: rule,
            timeZoneIdentifier: timeZoneID
        )?.month == 8)
    }

    /// Loaded from the shipped profile, never re-typed here. A local copy would
    /// keep passing against a pattern the profile no longer ships — a mutation
    /// run proved exactly that: breaking the profile's backreference left these
    /// behavioural assertions green.
    private func continentalCuentaPeriodRule() async throws -> DocumentPeriodRule {
        let profile = try #require(await BundledStatementProfileRepository().profile(id: "continental-cuenta"))
        return try #require(profile.documentPeriod)
    }
}
