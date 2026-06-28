//
//  flymoneyApp.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import SwiftUI
import CoreText

@main
struct flymoneyApp: App {
	var body: some Scene {
		WindowGroup {
			ContentView()
		}
	}
}

private struct ContentView: View {
	private let assembly: AppAssembly?

	init() {
		Self.registerFonts()
		do {
			self.assembly = try AppAssembly()
		} catch {
			self.assembly = nil
		}
	}

	private static func registerFonts() {
		guard let url = Bundle.main.url(forResource: "Sora", withExtension: "ttf") else { return }
		var error: Unmanaged<CFError>?
		CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
	}

	var body: some View {
		if let assembly {
			assembly.makeRootView()
		} else {
			VStack(spacing: Theme.Spacing.md) {
				Image(systemName: "exclamationmark.triangle")
					.font(.largeTitle)
					.foregroundStyle(Theme.Colors.danger)
				Text("Storage Unavailable")
					.font(Theme.Typography.title)
					.foregroundStyle(Theme.Colors.ink)
				Text("Unable to access the database. Please restart the app.")
					.font(Theme.Typography.body)
					.foregroundStyle(Theme.Colors.textSecondary)
					.multilineTextAlignment(.center)
			}
			.padding()
			.frame(maxWidth: .infinity, maxHeight: .infinity)
			.background(Theme.Colors.background)
		}
	}
}
