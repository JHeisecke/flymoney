//
//  TitleProgressMeter.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

struct TitleProgressMeter: View {
	let spent: Money
	let limit: Money

	var body: some View {
		GeometryReader { geo in
			ZStack(alignment: .leading) {
				RoundedRectangle(cornerRadius: Theme.Radius.xxs)
					.fill(Theme.Colors.neutralTint)
				RoundedRectangle(cornerRadius: Theme.Radius.xxs)
					.fill(BudgetStatus(spent: spent, limit: limit).color)
					.frame(width: max(0, min(1, ratio)) * geo.size.width)
			}
		}
		.frame(height: 7)
		.accessibilityLabel(Text(String(localized: "Budget used")))
		.accessibilityValue(Text(verbatim: "\(Int((ratio * 100).rounded()))%"))
	}

	private var ratio: Double {
		guard limit.minorUnits > 0 else { return 0 }
		return Double(spent.minorUnits) / Double(limit.minorUnits)
	}
}
