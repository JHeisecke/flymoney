//
//  MinesweeperViewModelTests.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-14.
//

import Foundation
import Testing
@testable import flymoney

@MainActor @Suite("MinesweeperViewModel")
struct MinesweeperViewModelTests {
    private func makeModel() -> MinesweeperViewModel {
        var generator = MinesweeperTestGenerator()
        return MinesweeperViewModel(game: MinesweeperGame(using: &generator))
    }

    @Test("Flag mode marks squares and a restart requires confirmation before clearing progress", .tags(.viewModel))
    func flagsAndRestart() {
        let model = makeModel()
        model.isFlagging = true
        model.play(at: 0)
        model.requestRestart()
        #expect(model.confirmRestart && model.game.cells[0].isFlagged)
        model.confirmRestart = false
        #expect(model.game.flagCount == 1)
        model.restart()
        #expect(!model.isFlagging && !model.confirmRestart)
        #expect(model.game.state == .ready && model.game.flagCount == 0)
        #expect(model.game.cells.allSatisfy { !$0.isRevealed && !$0.isMine })
    }

    @Test("Hidden accessibility labels never disclose mines or neighboring counts", .tags(.viewModel))
    func hiddenInformation() throws {
        let model = makeModel()
        let coveredLabel = model.cellLabel(model.game.cells[1])
        model.play(at: 0)
        let mine = try #require(model.game.cells.first { $0.isMine })
        let covered = MinesweeperCell(id: mine.id)
        #expect(model.cellLabel(mine) == model.cellLabel(covered))
        #expect(!coveredLabel.isEmpty)
        model.isFlagging = true
        model.play(at: mine.id)
        #expect(model.cellLabel(model.game.cells[mine.id]) != model.cellLabel(mine))
    }

    @Test("A finished game restarts directly instead of asking to discard progress", .tags(.viewModel))
    func finishedRestart() throws {
        let model = makeModel()
        model.play(at: 0)
        let mine = try #require(model.game.cells.first { $0.isMine })
        model.play(at: mine.id)
        #expect(model.game.state == .lost)
        model.requestRestart()
        #expect(model.game.state == .ready && !model.confirmRestart)
    }
    @Test("Difficulty changes before play are immediate; a restart keeps that difficulty", .tags(.viewModel),
        arguments: MinesweeperDifficulty.allCases)
    func selectAndRestart(difficulty: MinesweeperDifficulty) {
        let model = makeModel()
        model.requestDifficulty(difficulty)
        #expect(model.game.difficulty == difficulty && model.game.cells.count == difficulty.rows * difficulty.columns)
        #expect(!model.confirmRestart && model.pendingDifficulty == nil)
        model.isFlagging = true
        model.play(at: 0)
        let cells = model.game.cells
        model.requestDifficulty(difficulty)
        #expect(model.game.cells == cells && !model.confirmRestart)
        model.requestRestart()
        #expect(model.confirmRestart)
        model.restart()
        #expect(model.game.difficulty == difficulty && model.game.state == .ready)
        #expect(!model.isFlagging && model.game.remainingFlags == difficulty.mineCount)
    }

    @Test("Cancelling a difficulty change preserves progress and clears the pending level", .tags(.viewModel),
        arguments: [false, true])
    func cancelDifficultyChange(flagOnly: Bool) {
        let model = makeModel()
        model.isFlagging = flagOnly
        model.play(at: 0)
        let cells = model.game.cells
        model.requestDifficulty(.hard)
        #expect(model.confirmRestart && model.pendingDifficulty == .hard)
        #expect(model.game.difficulty == .easy && model.game.cells == cells)
        model.confirmRestart = false
        #expect(model.pendingDifficulty == nil && model.game.cells == cells)
        #expect(model.isFlagging == flagOnly)
        model.requestRestart()
        model.restart()
        #expect(model.game.difficulty == .easy)
        model.isFlagging = true
        model.play(at: 0)
        model.requestDifficulty(.medium)
        model.restart()
        #expect(model.game.difficulty == .medium && model.game.cells.count == 144)
        #expect(model.game.flagCount == 0 && model.game.state == .ready && !model.isFlagging)
    }

    @Test("A finished game accepts a different difficulty without discard confirmation", .tags(.viewModel))
    func changeAfterFinish() throws {
        let model = makeModel()
        model.play(at: 0)
        let mine = try #require(model.game.cells.first { $0.isMine })
        model.play(at: mine.id)
        model.requestDifficulty(.hard)
        #expect(model.game.difficulty == .hard && model.game.state == .ready && !model.confirmRestart)
    }

    @Test("Accessibility coordinates follow the current board width", .tags(.viewModel),
        arguments: MinesweeperDifficulty.allCases)
    func coordinates(difficulty: MinesweeperDifficulty) {
        let model = makeModel()
        model.requestDifficulty(difficulty)
        let label = model.cellLabel(model.game.cells[difficulty.columns])
        let expected = String(localized: "Row \(2), column \(1). \(String(localized: "Hidden"))")
        #expect(label == expected)
    }

}
