import Foundation

/// A statement's document period — resolved once per document from its header
/// text, and used to anchor year-less row dates (e.g. `d/M`).
public struct DocumentPeriod: Equatable, Sendable {
    public let year: Int
    /// Populated only when the profile's `documentPeriod.dateFormat` carries a
    /// month field. `nil` means the rule does not carry one — never "January".
    /// A row format that needs a month must fail rather than assume one.
    public let month: Int?

    public init(year: Int, month: Int? = nil) {
        self.year = year
        self.month = month
    }
}

/// One `DateFormatter` per parse, `en_US_POSIX` locale, profile's time zone and
/// format — never the device locale.
public enum DateResolver {
    /// Extracts the document period from the concatenated text of page 1 via
    /// the profile's `documentPeriod` rule. `nil` when the rule doesn't match —
    /// callers must treat a *declared* rule that fails to match as a hard
    /// failure, never a silent fallback to the current year.
    public static func extractDocumentPeriod(
        fullText: String,
        rule: DocumentPeriodRule,
        timeZoneIdentifier: String
    ) -> DocumentPeriod? {
        guard let regex = try? NSRegularExpression(pattern: rule.pattern) else { return nil }
        let range = NSRange(fullText.startIndex..., in: fullText)
        guard let match = regex.firstMatch(in: fullText, range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: fullText)
        else { return nil }

        let captured = String(fullText[captureRange])
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: timeZoneIdentifier)
        formatter.dateFormat = rule.dateFormat
        guard let date = formatter.date(from: captured) else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = formatter.timeZone
        let components = calendar.dateComponents([.year, .month], from: date)
        guard let year = components.year else { return nil }
        // Gated on the *format*, not on the parsed value: a year-only format
        // still parses to January, so `components.month` is never nil and
        // cannot itself distinguish "the rule carries a month" from "it does not".
        let month = rule.dateFormat.contains("M") ? components.month : nil
        return DocumentPeriod(year: year, month: month)
    }

    /// Resolves a row's date string. When `dateFormat` carries no year, the day
    /// is taken from the parse and recombined with `documentPeriod`'s year —
    /// never left at whatever default the formatter fills in. The month comes
    /// from the parse when the row format carries one, and from the document
    /// period when it does not (a bare day-of-month column).
    public static func resolveDate(
        _ raw: String,
        dateFormat: String,
        timeZoneIdentifier: String,
        documentPeriod: DocumentPeriod?
    ) -> Date? {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = dateFormat

        guard let parsed = formatter.date(from: raw) else { return nil }
        guard !dateFormat.contains("y") else { return parsed }

        guard let documentPeriod else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.month, .day], from: parsed)
        guard let day = components.day else { return nil }

        let month: Int
        if dateFormat.contains("M") {
            guard let parsedMonth = components.month else { return nil }
            month = parsedMonth
        } else {
            // The row prints a bare day; the month exists only at document
            // level. No fallback — `DateFormatter` defaults an absent month to
            // January, and filing a whole statement under the wrong month is a
            // silent data defect, worse than refusing to import.
            guard let periodMonth = documentPeriod.month else { return nil }
            month = periodMonth
        }

        var resolved = DateComponents()
        resolved.year = documentPeriod.year
        resolved.month = month
        resolved.day = day
        resolved.hour = 0
        resolved.minute = 0
        resolved.second = 0
        return calendar.date(from: resolved)
    }
}
