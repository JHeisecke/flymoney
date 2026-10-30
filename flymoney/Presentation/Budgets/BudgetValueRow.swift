//
//  BudgetValueRow.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-10-30.
//

import SwiftUI

struct BudgetValueRow: View {
	let title: LocalizedStringKey
	let value: String
	@Environment(\.dynamicTypeSize) private var dynamicTypeSize
	init(_ title: LocalizedStringKey, value: String) {
		self.title = title
		self.value = value
	}
	var body: some View {
		Group {
			if dynamicTypeSize.isAccessibilitySize {
				VStack(alignment: .leading, spacing: 8) {
					Text(title)
					Text(value).foregroundStyle(.secondary)
				}
				.accessibilityElement(children: .combine)
			} else {
				LabeledContent(title, value: value)
			}
		}
	}
}
