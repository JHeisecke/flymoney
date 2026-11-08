//
//  GuidesView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-07.
//

import SwiftUI

struct GuidesView: View {
	@Environment(\.dismiss) private var dismiss
	var body: some View {
		NavigationStack {
			List {
				Section("Getting started") {
					link(.firstExpense)
				}
				Section("Recurring payments") {
					link(.recurringExpense)
					link(.recurringList)
				}
				Section("Budgets and categories") {
					link(.shareBudget)
					link(.receiveBudget)
#if DEBUG
					link(.template)
#endif
					link(.category)
				}
				Section("Importing statements") {
					link(.statement)
				}
			}
			.navigationTitle("Guides")
			.navigationDestination(for: Guide.self) { guide in
				ScrollView {
					GuideInstructions(symbolName: guide.symbolName, points: guide.detail)
				}
				.navigationTitle(Text(guide.title))
				.navigationBarTitleDisplayMode(.inline)
			}
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					SheetCloseButton { dismiss() }
				}
			}
		}
	}
	private func link(_ guide: Guide) -> some View {
		NavigationLink(value: guide) {
			Label {
				Text(guide.title)
			} icon: {
				Image(systemName: guide.symbolName)
					.accessibilityHidden(true)
			}
		}
	}
}
