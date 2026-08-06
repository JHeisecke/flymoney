import Foundation

public protocol StatementProfileRepository: Sendable {
    func profiles(ofKind kind: StatementDocumentKind) async throws -> [StatementProfile]
    func profile(id: String) async throws -> StatementProfile?
}
