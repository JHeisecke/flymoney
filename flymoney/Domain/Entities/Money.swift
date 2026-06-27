import Foundation

struct Money: Equatable, Hashable, Sendable {
	let minorUnits: Int
	let currencyCode: String

	init(minorUnits: Int, currencyCode: String) {
		self.minorUnits = minorUnits
		self.currencyCode = currencyCode.uppercased()
	}

	static func zero(_ currencyCode: String) -> Money {
		Money(minorUnits: 0, currencyCode: currencyCode)
	}

	func adding(_ other: Money) throws -> Money {
		try requireSameCurrency(as: other)
		return Money(minorUnits: minorUnits + other.minorUnits, currencyCode: currencyCode)
	}

	func subtracting(_ other: Money) throws -> Money {
		try requireSameCurrency(as: other)
		return Money(minorUnits: minorUnits - other.minorUnits, currencyCode: currencyCode)
	}

	func formatted(locale: Locale = .current) -> String {
		let major = Decimal(minorUnits) / Decimal(Self.exponent(for: currencyCode))
		return major.formatted(
			.currency(code: currencyCode).locale(locale)
		)
	}

	private func requireSameCurrency(as other: Money) throws {
		guard currencyCode == other.currencyCode else {
			throw MoneyError.currencyMismatch(currencyCode, other.currencyCode)
		}
	}

	private static func exponent(for code: String) -> Int { 100 }
}
