//
//  NoopHapticsFeedback.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-30.
//

import Foundation

@MainActor
struct NoopHapticsFeedback: HapticsFeedback {
	func tap() {}
	func selection() {}
	func success() {}
	func warning() {}
	func error() {}
	func prepare() {}
}
