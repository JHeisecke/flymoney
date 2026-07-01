//
//  Color+Theme.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import SwiftUI

extension Theme {
	enum Colors {
		static let accent = Color(.accent)
		static let accentTint = Color(.accentTint)
		static let accentFocusRing = Color(.accentFocusRing)
		static let accentOnDark = Color.white

		static let ink = Color(.inkPrimary)
		static let inkSecondary = Color(.inkSecondary)
		static let inkTertiary = Color(.inkTertiary)
		static let inkQuaternary = Color(.inkQuaternary)
		static let textSubtle = Color(.textSubtle)
		static let textPlaceholder = Color(.textPlaceholder)
		static let textOnAccent = Color(.textOnAccent)

		static let surface = Color(.surface)
		static let surfaceDeepDark = Color(.surfaceDeepDark)
		static let surfaceElevatedDark = Color(.surfaceElevatedDark)
		static let card = Color(.card)
		static let cardElevated = Color(.cardElevated)
		static let scrim = Color(.scrim)

		static let borderHairline = Color(.borderHairline)
		static let borderDivider = Color(.borderDivider)
		static let borderSubtle = Color(.borderSubtle)
		static let borderStrong = Color(.borderStrong)

		static let success = Color(.success)
		static let successTint = Color(.successTint)
		static let warning = Color(.warning)
		static let warningTint = Color(.warningTint)
		static let danger = Color(.danger)
		static let dangerTint = Color(.dangerTint)
		static let neutralTint = Color(.neutralTint)

		static let segmentedTrack = Color(.segmentedTrack)
		static let segmentedThumb = Color(.segmentedThumb)
	}
}
