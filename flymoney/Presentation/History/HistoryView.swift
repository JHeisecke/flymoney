//
//  HistoryView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

struct HistoryView: View {
	@State private var viewModel: HistoryViewModel
	@State private var sharingRole: SharingRole?
	let assembly: AppAssembly

	init(viewModel: HistoryViewModel, assembly: AppAssembly) {
        self.viewModel = viewModel
		self.assembly = assembly
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			header
				.padding(.horizontal, Theme.Spacing.xxl)
				.padding(.top, Theme.Spacing.s18)
			MonthHeaderView(
				month: $viewModel.month,
				calendar: viewModel.calendar,
				onPrevious: { viewModel.previousMonth() },
				onNext: { viewModel.nextMonth() }
			)
				.padding(.horizontal, Theme.Spacing.xxl)
				.padding(.top, Theme.Spacing.md)
			HistoryHeroView(total: viewModel.totalSpent, titleCount: viewModel.titleCount)
				.padding(.horizontal, Theme.Spacing.xxl)
				.padding(.top, Theme.Spacing.s14)
			content
				.padding(.top, Theme.Spacing.s18)
		}
		.background(Theme.Colors.surface)
		.task { await viewModel.load() }
		.onChange(of: viewModel.month) { _, _ in
			Task { await viewModel.load() }
		}
		.alert("Error",
			   isPresented: errorAlertBinding,
			   actions: { Button(String(localized: "OK"), role: .cancel) {} },
			   message: { Text(viewModel.loadError ?? "") })
		.sheet(item: $sharingRole) { role in
			SharingSheetHost(assembly: assembly, role: role)
				.presentationDetents([.large])
		}
	}

	private var header: some View {
		HStack {
			Text(String(localized: "History"))
				.font(Theme.Typography.display27)
				.tracking(-0.5)
				.foregroundStyle(Theme.Colors.ink)
			Spacer()
			Menu {
				Button(String(localized: "Share this month"), systemImage: "qrcode") {
					sharingRole = .send(month: viewModel.month)
				}
				Button(String(localized: "Receive from a friend"), systemImage: "qrcode.viewfinder") {
					sharingRole = .receive
				}
			} label: {
				PillButton(title: "Share month", systemImage: nil, style: .outline) {}
					.allowsHitTesting(false)
			}
		}
	}

	@ViewBuilder private var content: some View {
		if viewModel.sections.isEmpty && !viewModel.isLoading {
			EmptyMonthState()
		} else {
			List {
				ForEach(viewModel.sections) { section in
					Section {
						ForEach(section.rows) { row in
							ExpenseRowView(row: row)
								.listRowInsets(EdgeInsets())
								.listRowSeparator(.visible, edges: .bottom)
								.listRowSeparatorTint(Theme.Colors.borderDivider)
								.listRowBackground(Theme.Colors.card)
						}
						.onDelete { offsets in
							for offset in offsets {
								let rowID = section.rows[offset].id
								Task { await viewModel.delete(rowID: rowID) }
							}
						}
					} header: {
						DaySectionHeader(label: sectionHeader(for: section.day))
					}
				}
			}
			.listStyle(.plain)
			.scrollIndicators(.hidden)
		}
	}

	private func sectionHeader(for day: Date) -> String {
		let cal = viewModel.calendar
		if cal.isDateInToday(day) { return String(localized: "Today") }
		if cal.isDateInYesterday(day) { return String(localized: "Yesterday") }
		return day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
	}

	private var errorAlertBinding: Binding<Bool> {
		Binding(
			get: { viewModel.loadError != nil },
			set: { if !$0 { viewModel.loadError = nil } }
		)
	}
}

private struct EmptyMonthState: View {
	var body: some View {
		ContentUnavailableView {
			Label {
				Text(String(localized: "No expenses this month"))
					.font(Theme.Typography.title17)
			} icon: {
				Image(systemName: "tray")
					.foregroundStyle(Theme.Colors.accent)
			}
		} description: {
			Text(String(localized: "Add an expense from the Add tab to get started."))
				.font(Theme.Typography.body14)
				.foregroundStyle(Theme.Colors.inkQuaternary)
		}
	}
}
