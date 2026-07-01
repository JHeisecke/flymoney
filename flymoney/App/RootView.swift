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
	let assembly: AppAssembly

	@Environment(\.haptics) private var haptics

	init(assembly: AppAssembly) {
		self.assembly = assembly
		_historyViewModel = State(initialValue: assembly.makeHistoryViewModel())
	}

	var body: some View {
        TabView(selection: $selection) {
            Tab("Add", systemImage: "plus.circle", value: TabID.add) {
                AddExpenseView(viewModel: assembly.makeAddExpenseViewModel())
            }
            Tab("History", systemImage: "list.bullet", value: TabID.history) {
                HistoryView(viewModel: historyViewModel, assembly: assembly)
            }
            Tab(value: TabID.titles) {
                TitlesView(viewModel: assembly.makeTitlesViewModel(), assembly: assembly)
            } label: {
                Label(title: { Text(Lexicon.Term.plural.text) }, icon: { Image(systemName: "tag") })
            }
		}
		.onChange(of: selection) { _, newValue in
			if newValue == .history {
				Task { await historyViewModel.load() }
			}
		}
		.tint(Theme.Colors.accent)
		.buttonStyle(.hapticPlain)
		.environment(\.haptics, HapticsManager())
		.onAppear { haptics.prepare() }
	}
}
