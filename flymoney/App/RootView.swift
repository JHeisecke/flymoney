import SwiftUI

struct RootView: View {
	enum TabID: Hashable { case add, history, titles }
	@State private var selection: TabID = .add

	var body: some View {
		TabView(selection: $selection) {
			Tab("Add", systemImage: "plus.circle", value: TabID.add) {
				PlaceholderScreen(title: "Add")
			}
			Tab("History", systemImage: "list.bullet", value: TabID.history) {
				PlaceholderScreen(title: "History")
			}
			Tab("Titles", systemImage: "tag", value: TabID.titles) {
				PlaceholderScreen(title: "Titles")
			}
		}
		.tint(Theme.Colors.accent)
	}
}
