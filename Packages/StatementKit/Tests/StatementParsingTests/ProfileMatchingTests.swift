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

    @Test("bundled repository exposes all three profiles across both kinds")
    func repositoryExposesAllProfiles() async throws {
        let cardProfiles = try await repository.profiles(ofKind: .creditCard)
        let accountProfiles = try await repository.profiles(ofKind: .bankAccount)
        #expect(Set(cardProfiles.map(\.id)) == ["gnb-extracto", "gnb-movimientos"])
        #expect(accountProfiles.map(\.id) == ["gnb-cuenta"])
    }
}
