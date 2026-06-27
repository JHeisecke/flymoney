import Foundation

protocol CurrencyProvider: Sendable {
	var defaultCurrencyCode: String { get }
}
