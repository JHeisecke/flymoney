//
//  Data+Base64URL.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import Foundation

extension Data {
	func base64URLEncodedString() -> String {
		base64EncodedString()
			.replacingOccurrences(of: "+", with: "-")
			.replacingOccurrences(of: "/", with: "_")
			.replacingOccurrences(of: "=", with: "")
	}

	init?(base64URLEncoded string: String) {
		var s = string
			.replacingOccurrences(of: "-", with: "+")
			.replacingOccurrences(of: "_", with: "/")
		while s.count % 4 != 0 { s += "=" }
		guard let data = Data(base64Encoded: s) else { return nil }
		self = data
	}
}
