import Foundation

/// Deliberately dumb: only safe, mechanical transforms. It never guesses that
/// two differently-worded rows are the same merchant — that grouping is the
/// user's decision, made once and remembered as an alias (Stage 16).
public enum DetailNormalizer {
    /// Decompose + strip diacritics, uppercase, collapse whitespace, trim, and
    /// strip a matching refund prefix so a refund normalizes toward the same
    /// key as the purchase it offsets.
    public static func normalize(_ raw: String, refundPrefixPatterns: [String] = []) -> String {
        let posix = Locale(identifier: "en_US_POSIX")
        var value = raw.folding(options: .diacriticInsensitive, locale: posix)
        value = value.uppercased(with: posix)
        value = collapseWhitespace(value)
        value = trim(value)
        value = stripRefundPrefix(value, patterns: refundPrefixPatterns)
        value = trim(value)
        return value
    }

    private static func collapseWhitespace(_ s: String) -> String {
        s.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func trim(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
    }

    private static func stripRefundPrefix(_ s: String, patterns: [String]) -> String {
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(s.startIndex..., in: s)
            guard let match = regex.firstMatch(in: s, range: range), match.range.location == 0,
                  let matchRange = Range(match.range, in: s)
            else { continue }
            return String(s[matchRange.upperBound...])
        }
        return s
    }
}
