//
//  Permissions.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import UIKit

enum Permissions {
	static func openSettings() {
		guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
		UIApplication.shared.open(url)
	}
}
