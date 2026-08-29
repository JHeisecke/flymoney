import Foundation

/// Scores profiles **within an already-decided kind** — a card profile is never
/// even scored against an account statement.
public protocol StatementProfileMatcher: Sendable {
    func match(pages: [TextPage], among profiles: [StatementProfile]) -> StatementProfile?
}

public struct DefaultStatementProfileMatcher: StatementProfileMatcher {
    public init() {}

    public func match(pages: [TextPage], among profiles: [StatementProfile]) -> StatementProfile? {
        guard let firstPage = pages.first else { return nil }
        let haystack = firstPage.words.map(\.text).joined(separator: " ")

        var best: (profile: StatementProfile, score: Int)?
        var tied = false
        for profile in profiles {
            let score = profile.detection.reduce(into: 0) { count, pattern in
                if haystack.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                    count += 1
                }
            }
            guard score >= profile.minimumDetectionScore else { continue }
            if let b = best {
                if score > b.score {
                    best = (profile, score)
                    tied = false
                } else if score == b.score {
                    tied = true
                }
            } else {
                best = (profile, score)
            }
        }
        // A tie means "cannot tell" — importing under the wrong bank's rules is
        // worse than surfacing `noProfile(for:)` and asking.
        return tied ? nil : best?.profile
    }
}
