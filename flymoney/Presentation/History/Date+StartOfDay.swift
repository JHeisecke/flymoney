//
//  Date+StartOfDay.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import Foundation

extension Date {
	func startOfDay(in calendar: Calendar) -> Date {
		calendar.startOfDay(for: self)
	}
}
