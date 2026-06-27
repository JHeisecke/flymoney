//
//  flymoneyApp.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import SwiftUI

@main
struct flymoneyApp: App {
	@State private var assembly = AppAssembly()

	var body: some Scene {
		WindowGroup {
			assembly.makeRootView()
		}
	}
}
