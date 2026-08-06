import Testing
import Foundation
@testable import StatementParsing

@Suite("gnb-movimientos end-to-end")
struct GNBMovimientosTests {
    private func parse() async throws -> StatementParseResult {
        let pages = try TestFixtures.pages("gnb-movimientos-pages")
        let repository = BundledStatementProfileRepository()
        let profile = try #require(await repository.profile(id: "gnb-movimientos"))
        return try DefaultStatementRowParser().parse(pages: pages, profile: profile)
    }

    @Test("21 transactions = 15 purchases + 6 refunds")
    func totalsAndSplit() async throws {
        let result = try await parse()
        #expect(result.transactions.count == 21)
        let refunds = result.transactions.filter(\.isRefund)
        #expect(refunds.count == 6)
        #expect(result.transactions.count - refunds.count == 15)
        #expect(result.issues.isEmpty)
    }

    @Test("SU PAGO rows are excluded")
    func suPagoExcluded() async throws {
        let result = try await parse()
        #expect(!result.transactions.contains { $0.rawDetail.hasPrefix("SU PAGO") })
    }

    @Test("wrapped details are rejoined — REINTEGRO + COPETROL becomes one row")
    func wrappedDetailsRejoined() async throws {
        let result = try await parse()
        #expect(result.transactions.contains { $0.rawDetail == "REINTEGRO COPETROL" })
    }

    @Test("transactions span both pages, with no table found on barcode-only pages")
    func spansBothPages() async throws {
        let result = try await parse()
        let pageIndices = Set(result.transactions.map(\.pageIndex))
        #expect(pageIndices == [0, 1])
    }

    @Test("this profile declares no sections — every transaction has a nil sectionKind")
    func flatLayoutHasNoSections() async throws {
        let result = try await parse()
        #expect(result.transactions.allSatisfy { $0.sectionKind == nil })
    }
}
