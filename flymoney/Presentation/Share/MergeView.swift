//
//  MergeView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

struct MergeView: View {
	@State private var viewModel: SharingViewModel

	init(viewModel: SharingViewModel) {
		_viewModel = State(initialValue: viewModel)
	}

	var body: some View {
		if case .awaitingMerge(let imported) = viewModel.phase {
			List {
				ForEach(imported.titles.sorted(by: { a, b in
					let spentA = imported.expenses.filter { $0.titleID == a.id }.reduce(0) { $0 + $1.amount.minorUnits }
					let spentB = imported.expenses.filter { $0.titleID == b.id }.reduce(0) { $0 + $1.amount.minorUnits }
					return spentA > spentB
				}), id: \.id) { title in
					let spent = imported.expenses.filter { $0.titleID == title.id }
						.reduce(Money.zero(imported.currencyCode)) { (try? $0.adding($1.amount)) ?? $0 }
					let res = Binding<MergeResolution>(
						get: { viewModel.resolutions[title.id] ?? .keepSeparate },
						set: { new in Task { await viewModel.setResolution(title.id, new) } }
					)
					MergeRowView(
						importedTitle: title,
						importedSpent: spent,
						localTitles: viewModel.localTitles,
						fuzzyMatches: viewModel.fuzzyMatches[title.id] ?? [],
						resolution: res)
				}

				Section(String(localized: "Combined total")) {
					ForEach(viewModel.combinedSummary, id: \.titleID) { summary in
						let name = viewModel.localTitles.first { $0.id == summary.titleID }?.name ?? "Untitled"
						HStack {
							Text(name)
								.font(Theme.Typography.body)
								.foregroundStyle(Theme.Colors.ink)
							Spacer()
							Text(summary.spent.formatted())
								.font(Theme.Typography.bodyMedium)
								.foregroundStyle(summary.isOver ? Theme.Colors.danger : Theme.Colors.success)
								.monospacedDigit()
						}
					}
				}
			}
			.listStyle(.plain)
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					Button(String(localized: "Save to my expenses")) {
						Task { await viewModel.saveToMyExpenses() }
					}
					.disabled(viewModel.phase == .saving || viewModel.phase == .done)
				}
			}
		}
	}
}
