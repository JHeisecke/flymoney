//
//  RootView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import SwiftUI

struct RootView: View {
	enum TabID: Hashable { case add, history, titles }
	@State private var selection: TabID = .add
	@State private var historyViewModel: HistoryViewModel
	@State private var titlesViewModel: TitlesViewModel
	@State private var addExpenseViewModel: AddExpenseViewModel
	let assembly: AppAssembly

	@Environment(\.haptics) private var haptics

	init(assembly: AppAssembly) {
		self.assembly = assembly
        self.historyViewModel = assembly.makeHistoryViewModel()
        self.titlesViewModel = assembly.makeTitlesViewModel()
        self.addExpenseViewModel = assembly.makeAddExpenseViewModel()
	}

	var body: some View {
        TabView(selection: $selection) {
            Tab("Add", systemImage: "plus.circle", value: TabID.add) {
                AddExpenseView(
                    viewModel: addExpenseViewModel, assembly: assembly,
                    onImportCompleted: { await refreshAfterImport() },
                    onViewImportInHistory: { selection = .history })
            }
            Tab("History", systemImage: "list.bullet", value: TabID.history) {
                HistoryView(viewModel: historyViewModel, assembly: assembly)
            }
            Tab(value: TabID.titles) {
                TitlesView(viewModel: titlesViewModel, assembly: assembly)
            } label: {
                Label(title: { Text(Lexicon.Term.plural.text) }, icon: { Image(systemName: "tag") })
            }
		}
		.onChange(of: selection) { _, newValue in
			if newValue == .history {
				Task { await historyViewModel.load() }
			} else if newValue == .titles {
				Task { await titlesViewModel.load() }
			}
		}
		.tint(Theme.Colors.accent)
		.buttonStyle(.hapticPlain)
		.environment(\.haptics, HapticsManager())
		.onAppear { haptics.prepare() }
	}

	/// A statement import commits on the Add tab, but its results live in
	/// History and Titles — and Add's own budget indicator can go stale too if
	/// a currently-selected title's spend just changed. `HistoryViewModel`
	/// only re-fetches titles when its cache is empty, so a plain `.load()`
	/// after an import that created new titles would miss them — `reloadTitles()`
	/// resets that cache first. `TitlesViewModel.load()` has no such cache, so
	/// a plain reload is enough there.
	private func refreshAfterImport() async {
		async let history: Void = historyViewModel.reloadTitles()
		async let titles: Void = titlesViewModel.load()
		async let budget: Void = addExpenseViewModel.refreshAfterExternalChange()
		_ = await (history, titles, budget)
	}
}
