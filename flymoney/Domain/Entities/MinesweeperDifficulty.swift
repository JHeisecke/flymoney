//
//  MinesweeperDifficulty.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-16.
//

enum MinesweeperDifficulty: String, CaseIterable, Identifiable, Sendable {
    case easy, medium, hard

    var id: Self { self }

    var columns: Int {
        switch self {
        case .easy: 8
        case .medium: 12
        case .hard: 16
        }
    }

    var rows: Int { columns }

    var mineCount: Int {
        switch self {
        case .easy: 10
        case .medium: 24
        case .hard: 40
        }
    }
}
