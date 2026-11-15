//
//  MinesweeperCell.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-14.
//

struct MinesweeperCell: Identifiable, Equatable {
    let id: Int
    var isMine = false
    var isRevealed = false
    var isFlagged = false
    var adjacentMines = 0
}
