//
//  HistoryView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

struct HistoryView: View {
	@State private var viewModel: HistoryViewModel

	init(viewModel: HistoryViewModel) {
		_viewModel = State(initialValue: viewModel)
	}

	var body: some View {
		NavigationStack {
			VStack(spacing: 0) {
				MonthPickerHeader(
					month: $viewModel.month,
					calendar: viewModel.calendar,
					onPrevious: { viewModel.previousMonth() },
					onNext: { viewModel.nextMonth() })

				Group {
					if viewModel.sections.isEmpty && !viewModel.isLoading {
						ContentUnavailableView {
							Label {
								Text(String(localized: "No expenses this month"))
							} icon: {
								Image(systemName: "tray")
									.foregroundStyle(Theme.Colors.accent)
							}
						} description: {
							Text(String(localized: "Add an expense from the Add tab to get started."))
						}
					} else {
						List {
							ForEach(viewModel.sections) { section in
								Section {
									ForEach(section.rows) { row in
										ExpenseRowView(row: row)
									}
									.onDelete { offsets in
										for offset in offsets {
											let rowID = section.rows[offset].id
											Task { await viewModel.delete(rowID: rowID) }
										}
									}
								} header: {
									Text(sectionHeader(for: section.day))
										.font(Theme.Typography.caption)
										.foregroundStyle(Theme.Colors.textSecondary)
								}
							}
						}
						.listStyle(.plain)
						.scrollIndicators(.hidden)
					}
				}
			}
			.navigationTitle(Text(String(localized: "History")))
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .topBarTrailing) {
					Button(String(localized: "Share"),
						   systemImage: "square.and.arrow.up") {
					}
					.disabled(true)
					.accessibilityHint(Text(String(localized: "Available in a future update")))
				}
			}
			.task { await viewModel.load() }
			.onChange(of: viewModel.month) { _, _ in
				Task { await viewModel.load() }
			}
			.alert("Error",
				   isPresented: errorAlertBinding,
				   actions: { Button(String(localized: "OK"), role: .cancel) {} },
				   message: { Text(viewModel.loadError ?? "") })
		}
		.tint(Theme.Colors.accent)
	}

	private func sectionHeader(for day: Date) -> String {
		let calendar = viewModel.calendar
		if calendar.isDateInToday(day) { return String(localized: "Today") }
		if calendar.isDateInYesterday(day) { return String(localized: "Yesterday") }
		return day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
	}

	private var errorAlertBinding: Binding<Bool> {
		Binding(
			get: { viewModel.loadError != nil },
			set: { if !$0 { viewModel.loadError = nil } }
		)
	}
}
