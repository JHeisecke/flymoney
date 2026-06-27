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
