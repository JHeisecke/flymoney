//
//  Color+Theme.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import SwiftUI

extension Color {
	init(hex: UInt32) {
		self.init(.sRGB,
				  red: Double((hex >> 16) & 0xFF) / 255,
				  green: Double((hex >> 8) & 0xFF) / 255,
				  blue: Double(hex & 0xFF) / 255,
				  opacity: 1)
	}
}

extension Theme {
	enum Colors {
		static let accent = Color(hex: 0x7C5CFF)
		static let ink = Color(hex: 0x0B0B0C)
		static let surface = Color(hex: 0xFFFFFF)
		static let background = Color(hex: 0xFBFBFC)
		static let textSecondary = Color(hex: 0x6A6A72)
		static let textTertiary = Color(hex: 0x9A9AA0)
		static let border = Color(hex: 0xECECEE)
		static let borderStrong = Color(hex: 0xE7E7EA)
		static let fill = Color(hex: 0xF1F1F3)
		static let success = Color(hex: 0x1F8A5B)
		static let successBg = Color(hex: 0xE7F4EC)
		static let danger = Color(hex: 0xD14343)
		static let warning = Color(hex: 0xC28A00)
		static let warningBg = Color(hex: 0xFBF3DF)
	}
}
