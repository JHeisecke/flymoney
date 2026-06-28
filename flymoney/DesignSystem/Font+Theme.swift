//
//  Font+Theme.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import SwiftUI
import CoreText

extension Theme {
	enum Typography {
		static let display66 = sora(.bold, size: 66, relativeTo: .largeTitle)
		static let display42 = sora(.bold, size: 42, relativeTo: .largeTitle)
		static let display27 = sora(.heavy, size: 27, relativeTo: .title)
		static let display24 = sora(.bold, size: 24, relativeTo: .title2)

		static let title17 = sora(.bold, size: 17, relativeTo: .headline)
		static let title16 = sora(.bold, size: 16, relativeTo: .headline)

		static let body17 = sora(.medium, size: 17, relativeTo: .body)
		static let body16 = sora(.medium, size: 16, relativeTo: .body)
		static let body15 = sora(.medium, size: 15, relativeTo: .body)
		static let body14 = sora(.medium, size: 14, relativeTo: .body)
		static let body13 = sora(.regular, size: 13, relativeTo: .footnote)

		static let caption13Strong = sora(.bold, size: 13, relativeTo: .footnote)
		static let caption12 = sora(.regular, size: 12, relativeTo: .caption)
		static let micro11 = sora(.bold, size: 11, relativeTo: .caption2)
		static let micro10 = sora(.bold, size: 10, relativeTo: .caption2)

		static let eyebrow11 = sora(.bold, size: 11, relativeTo: .caption2)
		static let eyebrow12 = sora(.bold, size: 12, relativeTo: .caption)

		@available(*, deprecated, renamed: "body16")
		static let body = sora(.regular, size: 17, relativeTo: .body)

		@available(*, deprecated, renamed: "body16")
		static let bodyMedium = sora(.medium, size: 17, relativeTo: .body)

		@available(*, deprecated, renamed: "display27")
		static let title = display27

		@available(*, deprecated, renamed: "caption12")
		static let caption = caption12

		@available(*, deprecated, renamed: "display66")
		static let display = display66

		private static func sora(_ weight: Font.Weight, size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
			guard let uiFont = soraUIFont(weight: weight, size: size) else {
				return Font.system(size: size, weight: weight, design: .rounded)
			}
			return Font(uiFont)
		}

		private static func soraUIFont(weight: Font.Weight, size: CGFloat) -> UIFont? {
			let variationWeight: CGFloat = switch weight {
			case .regular: 400
			case .medium: 500
			case .semibold: 600
			case .bold: 700
			case .heavy: 700
			default: 400
			}

			let descriptor = UIFontDescriptor(fontAttributes: [
				.family: "Sora",
				UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): [
					2003265652: variationWeight,
				],
			])

			return UIFont(descriptor: descriptor, size: size)
		}
	}
}
