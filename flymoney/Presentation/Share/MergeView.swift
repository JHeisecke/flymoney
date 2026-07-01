//
//  MergeView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

struct MergeView: View {
	@State private var viewModel: SharingViewModel
	@Environment(\.haptics) private var haptics
	let onDismiss: () -> Void

	init(viewModel: SharingViewModel, onDismiss: @escaping () -> Void) {
		_viewModel = State(initialValue: viewModel)
		self.onDismiss = onDismiss
	}

	var body: some View {
		Group {
			if case .awaitingMerge(let imported) = viewModel.phase {
				VStack(spacing: 0) {
					ShareSheetHeader(
						title: "Merge month",
						onCancel: onDismiss)

					ScrollView {
						VStack(spacing: Theme.Spacing.md) {
							ForEach(imported.titles, id: \.id) { title in
								let spent = spentFor(title.id, in: imported)
								MergeRowView(
									importedTitle: title,
									importedSpent: spent,
									localTitles: viewModel.localTitles,
									fuzzyMatches: viewModel.fuzzyMatches[title.id] ?? [],
									resolution: resolutionBinding(for: title.id))
							}
						}
						.padding(.horizontal, Theme.Spacing.s18)
						.padding(.bottom, Theme.Spacing.lg)
					}

					combinedTotalBar
				}
				.background(Theme.Colors.surface)
			}
		}
		.onChange(of: viewModel.phase) { _, phase in
			switch phase {
			case .done: haptics.success()
			case .failed: haptics.error()
			default: break
			}
		}
	}

	private var combinedTotalBar: some View {
		VStack(spacing: Theme.Spacing.md) {
			if let total = viewModel.combinedSummary.reduce(Money?.none, { partial, s in
				guard let p = partial else { return s.spent }
				return (try? p.adding(s.spent)) ?? p
			}) {
				HStack {
					Text(String(localized: "Combined total"))
						.font(Theme.Typography.body13)
						.foregroundStyle(Theme.Colors.inkTertiary)
					Spacer()
					Text(total.formatted())
						.font(Theme.Typography.display24)
						.foregroundStyle(Theme.Colors.ink)
						.monospacedDigit()
				}
				.padding(.horizontal, Theme.Spacing.s22)
			}
			SaveButton(
				title: "Save to my expenses",
				isLoading: viewModel.phase == .saving,
				isDisabled: viewModel.phase == .done) {
					Task { await viewModel.saveToMyExpenses(); onDismiss() }
				}
				.padding(.horizontal, Theme.Spacing.s22)
				.padding(.bottom, Theme.Spacing.s30)
		}
		.padding(.top, Theme.Spacing.s18)
		.background(Theme.Colors.card)
		.overlay(alignment: .top) {
			Rectangle()
				.fill(Theme.Colors.borderHairline)
				.frame(height: 1)
		}
	}

	private func spentFor(_ id: UUID, in imported: ImportedMonth) -> Money {
		imported.expenses
			.filter { $0.titleID == id }
			.reduce(Money.zero(imported.currencyCode)) { (try? $0.adding($1.amount)) ?? $0 }
	}

	private func resolutionBinding(for id: UUID) -> Binding<MergeResolution?> {
		Binding(
			get: { viewModel.resolutions[id] },
			set: { newValue in
				guard let newValue else { return }
				Task { await viewModel.setResolution(id, newValue) }
			})
	}
}
