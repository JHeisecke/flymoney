import Testing
@testable import StatementParsing

@Suite("DefaultStatementRowParser orchestration")
struct StatementRowParserOrchestrationTests {
    @Test("unrecognised kind and known-kind-no-profile are distinct errors")
    func distinctErrorsForUnrecognisedKindAndNoProfile() async throws {
        let nonStatementPage = TextPage(index: 0, width: 100, height: 100, words: [
            PositionedWord(text: "HELLO", minX: 0, maxX: 10, midY: 50),
        ])
        await #expect(throws: StatementParseError.unrecognisedDocumentKind) {
            _ = try await DefaultStatementRowParser().parse(pages: [nonStatementPage])
        }

        // A page that scores as .creditCard but matches no bundled profile.
        let cardLikePage = TextPage(index: 0, width: 100, height: 100, words: [
            PositionedWord(text: "MASTERCARD", minX: 0, maxX: 10, midY: 50),
            PositionedWord(text: "VISA", minX: 0, maxX: 10, midY: 40),
        ])
        await #expect(throws: StatementParseError.noProfile(for: .creditCard)) {
            _ = try await DefaultStatementRowParser().parse(pages: [cardLikePage])
        }
    }

    @Test("end-to-end via the convenience overload resolves the same profile as the explicit one")
    func convenienceOverloadResolvesCorrectProfile() async throws {
        let pages = try TestFixtures.pages("gnb-extracto-pages")
        let result = try await DefaultStatementRowParser().parse(pages: pages)
        #expect(result.transactions.count == 36)
    }
}
