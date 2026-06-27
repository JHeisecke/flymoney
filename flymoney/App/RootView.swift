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

	var body: some View {
		TabView(selection: $selection) {
			Tab("Add", systemImage: "plus.circle", value: TabID.add) {
				PlaceholderScreen(title: "Add")
			}
			Tab("History", systemImage: "list.bullet", value: TabID.history) {
				PlaceholderScreen(title: "History")
			}
			Tab("Titles", systemImage: "tag", value: TabID.titles) {
				TitlesView(viewModel: assembly.makeTitlesViewModel())
			}
		}
		.tint(Theme.Colors.accent)
	}
}
