import Testing
@testable import StatementParsing

/// Cross-checks every fixture against every profile of its kind. Would have
/// caught Itaú scoring a confident match against `gnb-extracto` (§2 of the
/// Stage 19 plan) — a collision `DefaultStatementProfileMatcher.match` alone
/// hides, since it silently keeps the first-scoring winner instead of
/// surfacing that more than one profile claimed the document.
@Suite("Profile uniqueness")
struct ProfileUniquenessTests {
    private static let fixtures: [(name: String, kind: StatementDocumentKind)] = [
        ("gnb-extracto-pages", .creditCard),
        ("gnb-movimientos-pages", .creditCard),
        ("gnb-cuenta-pages", .bankAccount),
        ("itau-pages", .creditCard),
        ("continental-pages", .creditCard),
    ]

    private let repository = BundledStatementProfileRepository()

    /// Mirrors `DefaultStatementProfileMatcher`'s scoring, but returns every
    /// profile that clears its own threshold rather than only the best —
    /// the matcher's job is picking a winner, this test's job is checking
    /// there is only ever one contender to pick from.
    private func candidates(pages: [TextPage], profiles: [StatementProfile]) -> [StatementProfile] {
        guard let firstPage = pages.first else { return [] }
        let haystack = firstPage.words.map(\.text).joined(separator: " ")
        return profiles.filter { profile in
            let score = profile.detection.reduce(into: 0) { count, pattern in
                if haystack.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                    count += 1
                }
            }
            return score >= profile.minimumDetectionScore
        }
    }

    @Test("every fixture matches exactly one profile of its kind", arguments: fixtures)
    func exactlyOneMatch(fixture: (name: String, kind: StatementDocumentKind)) async throws {
        let pages = try TestFixtures.pages(fixture.name)
        let profiles = try await repository.profiles(ofKind: fixture.kind)
        let matches = candidates(pages: pages, profiles: profiles)
        #expect(
            matches.count == 1,
            "\(fixture.name) matched \(matches.count) profiles: \(matches.map(\.id))"
        )
    }
}
