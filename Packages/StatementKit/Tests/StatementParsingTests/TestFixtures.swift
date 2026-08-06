import Foundation
@testable import StatementParsing

enum TestFixtures {
    static func pages(_ name: String) throws -> [TextPage] {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json") else {
            throw FixtureError.missing(name)
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([TextPage].self, from: data)
    }
}

enum FixtureError: Error { case missing(String) }
