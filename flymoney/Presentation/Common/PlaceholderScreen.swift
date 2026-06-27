import SwiftUI

struct PlaceholderScreen: View {
	let title: LocalizedStringKey

	var body: some View {
		ZStack {
			Theme.Colors.background.ignoresSafeArea()
			Text(title)
				.font(Theme.Typography.title)
				.foregroundStyle(Theme.Colors.ink)
		}
	}
}
