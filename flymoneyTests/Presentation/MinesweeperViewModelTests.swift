//
//  MinesweeperViewModelTests.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-14.
//

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
}
