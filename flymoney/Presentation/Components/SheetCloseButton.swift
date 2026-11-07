//
//  SheetCloseButton.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-07.
//

import SwiftUI

struct SheetCloseButton: View {
	let action: () -> Void

	var body: some View {
		Button(action: action) {
			Label("Close", systemImage: "xmark")
				.labelStyle(.iconOnly)
				.foregroundStyle(Theme.Colors.ink)
				.frame(width: 44, height: 44)
				.contentShape(.rect)
		}
		.buttonStyle(.hapticPlain)
	}
}
