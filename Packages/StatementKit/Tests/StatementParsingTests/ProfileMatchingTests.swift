import Testing
@testable import StatementParsing

@Suite("StatementProfileMatcher")
struct ProfileMatchingTests {
    private let matcher = DefaultStatementProfileMatcher()
    private let repository = BundledStatementProfileRepository()

    @Test("gnb-extracto fixture picks the gnb-extracto profile")
    func extractoPicksItsProfile() async throws {
        let pages = try TestFixtures.pages("gnb-extracto-pages")
        let profiles = try await repository.profiles(ofKind: .creditCard)
        let match = matcher.match(pages: pages, among: profiles)
        #expect(match?.id == "gnb-extracto")
    }

    @Test("gnb-movimientos fixture picks the gnb-movimientos profile")
    func movimientosPicksItsProfile() async throws {
        let pages = try TestFixtures.pages("gnb-movimientos-pages")
        let profiles = try await repository.profiles(ofKind: .creditCard)
        let match = matcher.match(pages: pages, among: profiles)
        #expect(match?.id == "gnb-movimientos")
    }

    @Test("gnb-cuenta fixture picks the gnb-cuenta profile")
    func cuentaPicksItsProfile() async throws {
        let pages = try TestFixtures.pages("gnb-cuenta-pages")
        let profiles = try await repository.profiles(ofKind: .bankAccount)
        let match = matcher.match(pages: pages, among: profiles)
        #expect(match?.id == "gnb-cuenta")
    }

    @Test("card profiles are never scored against the account statement")
    func cardProfilesNeverScoredAgainstAccountStatement() async throws {
        let pages = try TestFixtures.pages("gnb-cuenta-pages")
        let cardProfiles = try await repository.profiles(ofKind: .creditCard)
        #expect(matcher.match(pages: pages, among: cardProfiles) == nil)
    }

    @Test("a non-statement PDF scores below threshold")
    func nonStatementScoresBelowThreshold() async throws {
        let page = TextPage(index: 0, width: 100, height: 100, words: [
            PositionedWord(text: "HELLO", minX: 0, maxX: 10, midY: 50),
        ])
        let profiles = try await repository.profiles(ofKind: .creditCard)
        #expect(matcher.match(pages: [page], among: profiles) == nil)
    }

    @Test("bundled repository exposes all card and account profiles")
    func repositoryExposesAllProfiles() async throws {
        let cardProfiles = try await repository.profiles(ofKind: .creditCard)
        let accountProfiles = try await repository.profiles(ofKind: .bankAccount)
        #expect(Set(cardProfiles.map(\.id)) == ["gnb-extracto", "gnb-movimientos", "itau-extracto", "continental-extracto"])
        #expect(accountProfiles.map(\.id) == ["gnb-cuenta"])
    }

    /// `continental-extracto`'s detection depends on the matcher NOT folding
    /// diacritics — its discriminator is the accented "FEC. OPERACIÓN", where
    /// GNB/Itaú print the unaccented "FEC. OPERACION". Pinned so a future
    /// "normalise accents" change to the matcher fails loudly instead of
    /// silently merging Continental into another profile.
    @Test("matcher does not fold diacritics — accented pattern matches only accented text")
    func matcherIsNotDiacriticInsensitive() {
        let accentedProfile = StatementProfile(
            id: "accented-test",
            displayName: "Accented test",
            bankID: "test",
            currencyCode: "PYG",
            timeZoneIdentifier: "America/Asuncion",
            detection: ["FEC\\. OPERACIÓN"],
            minimumDetectionScore: 1,
            tableHeaderPatterns: [],
            columns: [],
            dateFormat: "dd/MM/yy",
            groupingSeparator: ".",
            decimalSeparator: ",",
            documentPeriod: nil,
            yTolerance: 3.0,
            rules: .creditCard(CreditCardRules(
                sections: [], excludeDetailPatterns: [], excludeWhenColumnsPresent: [],
                refundPrefixPatterns: [], deferredAmount: nil
            ))
        )
        let accentedPage = TextPage(index: 0, width: 100, height: 100, words: [
            PositionedWord(text: "FEC.", minX: 0, maxX: 10, midY: 50),
            PositionedWord(text: "OPERACIÓN", minX: 12, maxX: 40, midY: 50),
        ])
        let unaccentedPage = TextPage(index: 0, width: 100, height: 100, words: [
            PositionedWord(text: "FEC.", minX: 0, maxX: 10, midY: 50),
            PositionedWord(text: "OPERACION", minX: 12, maxX: 40, midY: 50),
        ])
        #expect(matcher.match(pages: [accentedPage], among: [accentedProfile])?.id == "accented-test")
        #expect(matcher.match(pages: [unaccentedPage], among: [accentedProfile]) == nil)
    }

    @Test("two profiles tied on detection score resolve to nil, not first-wins")
    func tiedScoresResolveToNil() {
        func profile(id: String, detection: [String]) -> StatementProfile {
            StatementProfile(
                id: id,
                displayName: id,
                bankID: "test",
                currencyCode: "PYG",
                timeZoneIdentifier: "America/Asuncion",
                detection: detection,
                minimumDetectionScore: 1,
                tableHeaderPatterns: [],
                columns: [],
                dateFormat: "dd/MM/yy",
                groupingSeparator: ".",
                decimalSeparator: ",",
                documentPeriod: nil,
                yTolerance: 3.0,
                rules: .creditCard(CreditCardRules(
                    sections: [], excludeDetailPatterns: [], excludeWhenColumnsPresent: [],
                    refundPrefixPatterns: [], deferredAmount: nil
                ))
            )
        }
        let page = TextPage(index: 0, width: 100, height: 100, words: [
            PositionedWord(text: "SHARED", minX: 0, maxX: 10, midY: 50),
        ])
        // "a-profile" sorts before "b-profile" — proves the tie isn't broken by iteration order.
        let profiles = [profile(id: "a-profile", detection: ["SHARED"]), profile(id: "b-profile", detection: ["SHARED"])]
        #expect(matcher.match(pages: [page], among: profiles) == nil)
    }
}
