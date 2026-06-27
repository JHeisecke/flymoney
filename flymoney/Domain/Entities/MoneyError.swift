import Foundation

enum MoneyError: Error, Equatable, Sendable {
	case currencyMismatch(String, String)
}
