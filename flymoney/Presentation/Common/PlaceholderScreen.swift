//
//  PlaceholderScreen.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

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
