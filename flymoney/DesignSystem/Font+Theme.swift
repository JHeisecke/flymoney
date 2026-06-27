//
//  Font+Theme.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import SwiftUI

extension Theme {
	enum Typography {
		// TODO: Bundle Sora variable font (Sora[wght].ttf) from
		// https://github.com/google/fonts/tree/main/ofl/sora
		// Register via Info.plist UIAppFonts, use UIFontDescriptor
		// to select weight instances, wrap in Font(font).
		// Until then, fall back to system rounded for display/title.
		static let display = Font.system(.largeTitle, design: .rounded).bold()
		static let title = Font.system(.title, design: .rounded).weight(.semibold)
		static let body = Font.body
		static let bodyMedium = Font.body.weight(.medium)
		static let caption = Font.subheadline
	}
}
