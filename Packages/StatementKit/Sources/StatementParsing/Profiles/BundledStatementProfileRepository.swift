import Foundation

/// Profiles live in kind-partitioned resource directories — a card profile
/// physically cannot pick up account-only fields, and a malformed profile fails
/// at load with a decode error rather than silently parsing as `nil` later.
public struct BundledStatementProfileRepository: StatementProfileRepository {
    public init() {}

    public func profiles(ofKind kind: StatementDocumentKind) async throws -> [StatementProfile] {
        guard let urls = Bundle.module.urls(
            forResourcesWithExtension: "json",
            subdirectory: "BankProfiles/\(kind.resourceDirectoryName)"
        ) else { return [] }

        let decoder = JSONDecoder()
        return try urls
            .map { try decoder.decode(StatementProfile.self, from: Data(contentsOf: $0)) }
            .sorted { $0.id < $1.id }
    }

    public func profile(id: String) async throws -> StatementProfile? {
        for kind in StatementDocumentKind.allCases {
            if let match = try await profiles(ofKind: kind).first(where: { $0.id == id }) {
                return match
            }
        }
        return nil
    }
}

private extension StatementDocumentKind {
    var resourceDirectoryName: String {
        switch self {
        case .creditCard: "CreditCard"
        case .bankAccount: "Account"
        }
    }
}
