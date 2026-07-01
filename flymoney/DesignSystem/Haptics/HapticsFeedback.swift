//
//  HapticsFeedback.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-30.
//

import Foundation

@MainActor
protocol HapticsFeedback: Sendable {
	func tap()
	func selection()
	func success()
	func warning()
	func error()
	func prepare()
}
