//
//  Permissions.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import UIKit

enum Permissions {
	/// Main-actor because `UIApplication.shared` is. Every caller is a SwiftUI
	/// view, so this costs them nothing.
	@MainActor
	static func openSettings() {
		guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
		UIApplication.shared.open(url)
	}
}
