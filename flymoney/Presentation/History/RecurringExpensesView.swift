//
//  RecurringExpensesView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-07.
//

import SwiftUI

struct RecurringExpensesView: View {
	@Environment(\.dismiss) private var dismiss
	@State private var viewModel: RecurringExpensesViewModel
	@State private var loadAttempt = 0

	init(viewModel: RecurringExpensesViewModel) {
		_viewModel = State(initialValue: viewModel)
	}

	var body: some View {
		NavigationStack {
			Group {
				switch viewModel.phase {
				case .loading:
					ProgressView()
				case .loaded(let sections) where sections.isEmpty:
					ContentUnavailableView("No recurring expenses yet", systemImage: "arrow.clockwise")
				case .loaded(let sections):
					List(sections) { section in
						Section {
							ForEach(section.rows) { row in
								ExpenseRowView(row: row, showsRecordedDate: true)
									.accessibilityElement(children: .combine)
									.listRowInsets(EdgeInsets())
									.listRowSeparatorTint(Theme.Colors.borderDivider)
									.listRowBackground(Theme.Colors.card)
							}
						} header: {
							DaySectionHeader(label: section.start.formatted(.dateTime.month(.wide).year()))
						}
					}
					.listStyle(.plain)
					.scrollContentBackground(.hidden)
				case .failed:
					ContentUnavailableView {
						Label("Couldn’t load recurring expenses", systemImage: "exclamationmark.circle")
					} actions: {
						Button("Try again") { loadAttempt += 1 }
					}
				}
			}
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.background(Theme.Colors.surface)
			.navigationTitle("Recurring expenses")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					Button("Done") { dismiss() }
				}
			}
		}
		.task(id: loadAttempt) { await viewModel.load() }
	}
}
