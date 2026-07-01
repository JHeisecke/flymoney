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
	let assembly: AppAssembly

	@Environment(\.haptics) private var haptics

	var body: some View {
		TabView(selection: $selection) {
			Tab("Add", systemImage: "plus.circle", value: TabID.add) {
				AddExpenseView(viewModel: assembly.makeAddExpenseViewModel())
			}
			Tab("History", systemImage: "list.bullet", value: TabID.history) {
				HistoryView(viewModel: assembly.makeHistoryViewModel(), assembly: assembly)
			}
			Tab(value: TabID.titles) {
				TitlesView(viewModel: assembly.makeTitlesViewModel())
			} label: {
				Label(title: { Text(Lexicon.Term.plural.text) }, icon: { Image(systemName: "tag") })
			}
		}
		.tint(Theme.Colors.accent)
		.preferredColorScheme(.light)
		.buttonStyle(.hapticPlain)
		.environment(\.haptics, HapticsManager())
		.onAppear { haptics.prepare() }
	}
}
