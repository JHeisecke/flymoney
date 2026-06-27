import Foundation
@testable import flymoney

struct FixedCurrencyProvider: CurrencyProvider {
	let defaultCurrencyCode: String

	init(_ code: String = "USD") {
		self.defaultCurrencyCode = code
	}
}
