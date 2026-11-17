//
//  MinesweeperViewModel.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-14.
//

import Foundation
import Observation

@MainActor @Observable
final class MinesweeperViewModel {
    private(set) var game: MinesweeperGame
    var isFlagging = false
    private(set) var pendingDifficulty: MinesweeperDifficulty?
    var confirmRestart = false {
        didSet {
            if !confirmRestart { pendingDifficulty = nil }
        }
    }

    init(game: MinesweeperGame = MinesweeperGame()) {
        self.game = game
    }

    func play(at id: Int) {
        if isFlagging { game.toggleFlag(at: id) }
        else { game.reveal(at: id) }
    }

    private var hasProgress: Bool {
        !game.state.isFinished && (game.state == .playing || game.flagCount > 0)
    }

    func requestDifficulty(_ difficulty: MinesweeperDifficulty) {
        guard difficulty != game.difficulty else { return }
        pendingDifficulty = difficulty
        if hasProgress { confirmRestart = true }
        else { restart() }
    }

    func requestRestart() {
        pendingDifficulty = nil
        if hasProgress {
            confirmRestart = true
        } else {
            restart()
        }
    }

    func restart() {
        game = MinesweeperGame(difficulty: pendingDifficulty ?? game.difficulty)
        isFlagging = false
        confirmRestart = false
    }

    func difficultyName(_ difficulty: MinesweeperDifficulty) -> String {
        switch difficulty {
        case .easy: String(localized: "Easy")
        case .medium: String(localized: "Medium")
        case .hard: String(localized: "Hard")
        }
    }

    var statusTitle: String {
        switch game.state {
        case .ready: String(localized: "A little break")
        case .playing: String(localized: "Watch your step")
        case .won: String(localized: "You cleared the board!")
        case .lost: String(localized: "You found a mine")
        }
    }

    var statusMessage: String {
        switch game.state {
        case .ready: String(localized: "Find the \(game.mineCount) mines. Your first reveal is safe.")
        case .playing: String(localized: "Reveal every safe square to win.")
        case .won: String(localized: "All safe squares are clear. Play again?")
        case .lost: String(localized: "No worries. A new board is one tap away.")
        }
    }

    func cellLabel(_ cell: MinesweeperCell) -> String {
        let row = cell.id / game.columns + 1
        let column = cell.id % game.columns + 1
        let detail: String
        if game.state == .lost, cell.isFlagged, !cell.isMine {
            detail = String(localized: "Incorrect flag")
        } else if game.state.isFinished, cell.isMine {
            detail = cell.id == game.detonatedCellID
                ? String(localized: "Exploded mine") : String(localized: "Mine")
        } else if cell.isFlagged {
            detail = String(localized: "Flagged")
        } else if cell.isRevealed {
            detail = cell.adjacentMines == 0
                ? String(localized: "Empty") : String(localized: "Nearby mines: \(cell.adjacentMines)")
        } else {
            detail = String(localized: "Hidden")
        }
        return String(localized: "Row \(row), column \(column). \(detail)")
    }

    var cellHint: String {
        isFlagging
            ? String(localized: "Double-tap to place or remove a flag.")
            : String(localized: "Double-tap to reveal. Switch to Flag to mark a square.")
    }
}
