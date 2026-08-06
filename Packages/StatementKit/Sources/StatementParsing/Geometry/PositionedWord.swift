import Foundation

/// One word reconstructed from character geometry. `Double`, not `CGFloat` —
/// this target must not import CoreGraphics.
public struct PositionedWord: Equatable, Sendable, Codable {
    public let text: String
    public let minX: Double
    public let maxX: Double
    public let midY: Double

    public init(text: String, minX: Double, maxX: Double, midY: Double) {
        self.text = text
        self.minX = minX
        self.maxX = maxX
        self.midY = midY
    }

    public var centerX: Double { (minX + maxX) / 2 }
}

/// Extractor output. Flat — banding into logical rows is a separate parsing step.
public struct TextPage: Equatable, Sendable, Codable {
    public let index: Int
    public let width: Double
    public let height: Double
    /// Top-to-bottom, then left-to-right.
    public let words: [PositionedWord]

    public init(index: Int, width: Double, height: Double, words: [PositionedWord]) {
        self.index = index
        self.width = width
        self.height = height
        self.words = words
    }
}

/// Output of the row-banding step, using the profile's `yTolerance`.
public struct TextRow: Equatable, Sendable {
    public let midY: Double
    /// Sorted by `minX`.
    public let words: [PositionedWord]

    public init(midY: Double, words: [PositionedWord]) {
        self.midY = midY
        self.words = words
    }
}
