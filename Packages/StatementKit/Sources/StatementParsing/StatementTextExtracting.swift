import Foundation

/// The seam that keeps PDFKit (or a future Vision OCR implementation) out of
/// the pure parsing target. No profile, no `yTolerance` — banding into logical
/// rows is a separate, profile-driven parsing step.
public protocol StatementTextExtracting: Sendable {
    func extract(fileURL: URL, gapTolerance: Double) async throws -> [TextPage]
}
