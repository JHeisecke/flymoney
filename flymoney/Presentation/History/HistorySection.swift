//
//  HistorySection.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import Foundation

struct HistorySection: Identifiable, Equatable, Sendable {
	let id: Date
	let day: Date
	let rows: [HistoryRow]
}

struct HistoryRow: Identifiable, Equatable, Sendable {
	let id: UUID
	let titleName: String
	let amount: Money
	let date: Date
}
