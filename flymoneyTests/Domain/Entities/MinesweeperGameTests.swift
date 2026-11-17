//
//  MinesweeperGameTests.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-14.
//

import Testing
@testable import flymoney

@Suite("MinesweeperGame")
struct MinesweeperGameTests {
    private func makeGame(_ difficulty: MinesweeperDifficulty = .easy) -> MinesweeperGame {
        var generator = MinesweeperTestGenerator()
        return MinesweeperGame(difficulty: difficulty, using: &generator)
    }

    @Test("Every first reveal is safe and places the configured mine count", .tags(.entity),
        arguments: MinesweeperDifficulty.allCases)
    func safeFirstReveal(difficulty: MinesweeperDifficulty) {
        let cellCount = difficulty.rows * difficulty.columns
        for id in 0..<cellCount {
            var game = makeGame(difficulty)
            #expect(game.cells.allSatisfy { !$0.isMine && !$0.isRevealed })
            game.reveal(at: id)
            #expect(!game.cells[id].isMine && game.cells[id].isRevealed)
            #expect(game.cells.filter(\.isMine).count == difficulty.mineCount)
            #expect(game.state != .lost)
        }
    }

    @Test("Difficulty presets expose the intended dimensions and mine counts", .tags(.entity))
    func difficultyPresets() {
        #expect(MinesweeperDifficulty.allCases.map(\.columns) == [8, 12, 16])
        #expect(MinesweeperDifficulty.allCases.map(\.rows) == [8, 12, 16])
        #expect(MinesweeperDifficulty.allCases.map(\.mineCount) == [10, 24, 40])
        #expect(MinesweeperGame().difficulty == .easy)
    }

    @Test("Corner, edge and middle counts do not wrap across rows", .tags(.entity),
        arguments: MinesweeperDifficulty.allCases)
    func neighborCounts(difficulty: MinesweeperDifficulty) {
        var game = makeGame(difficulty)
        game.reveal(at: 0)
        let c = game.columns
        let last = game.cells.count - 1
        for (id, neighbors) in [(0, [1, c, c + 1]), (c - 1, [c - 2, 2 * c - 2, 2 * c - 1]),
            (1, [0, 2, c, c + 1, c + 2]),
            (c + 1, [0, 1, 2, c, c + 2, 2 * c, 2 * c + 1, 2 * c + 2]),
            (last, [last - c - 1, last - c, last - 1])] {
            #expect(game.cells[id].adjacentMines == neighbors.filter { game.cells[$0].isMine }.count)
        }
    }

    @Test("Flags do not start the game, block reveals and cannot exceed the mine count", .tags(.entity), arguments: MinesweeperDifficulty.allCases)
    func flagsBeforeFirstReveal(difficulty: MinesweeperDifficulty) {
        var game = makeGame(difficulty)
        for id in 0..<(game.mineCount + 1) { game.toggleFlag(at: id) }
        #expect(game.flagCount == game.mineCount && game.remainingFlags == 0)
        #expect(!game.cells[game.mineCount].isFlagged && game.state == .ready)
        game.reveal(at: 0)
        #expect(game.state == .ready && !game.cells[0].isRevealed)
        game.toggleFlag(at: 0)
        game.reveal(at: 0)
        #expect(!game.cells[0].isMine && game.cells[0].isRevealed)
        game.toggleFlag(at: 0)
        #expect(!game.cells[0].isFlagged)
    }

    @Test("Revealing an empty region exposes its numbered border but preserves flags", .tags(.entity), arguments: MinesweeperDifficulty.allCases)
    func emptyRegion(difficulty: MinesweeperDifficulty) throws {
        var game = makeGame(difficulty)
        game.reveal(at: 0)
        let empty = try #require(game.cells.first { !$0.isMine && !$0.isRevealed && $0.adjacentMines == 0 })
        let flag = try #require(game.cells.first {
            !$0.isMine && !$0.isRevealed && $0.id != empty.id &&
            abs($0.id / game.columns - empty.id / game.columns) <= 1 && abs($0.id % game.columns - empty.id % game.columns) <= 1
        })
        game.toggleFlag(at: flag.id)
        game.reveal(at: empty.id)
        #expect(game.cells[empty.id].isRevealed)
        #expect(!game.cells[flag.id].isRevealed && game.cells[flag.id].isFlagged)
        for cell in game.cells where cell.isRevealed && cell.adjacentMines == 0 {
            for adjacent in game.cells where abs(adjacent.id / game.columns - cell.id / game.columns) <= 1 &&
                abs(adjacent.id % game.columns - cell.id % game.columns) <= 1 && !adjacent.isFlagged {
                #expect(adjacent.isRevealed && !adjacent.isMine)
            }
        }
    }

    @Test("Finding a mine ends the game and freezes further moves", .tags(.entity), arguments: MinesweeperDifficulty.allCases)
    func losingGame(difficulty: MinesweeperDifficulty) throws {
        var game = makeGame(difficulty)
        game.reveal(at: 0)
        let mine = try #require(game.cells.first { $0.isMine })
        game.reveal(at: mine.id)
        #expect(game.state == .lost && game.detonatedCellID == mine.id)
        let cells = game.cells
        for id in game.cells.indices { game.reveal(at: id); game.toggleFlag(at: id) }
        #expect(game.cells == cells)
    }

    @Test("All safe cells must be revealed to win, without requiring flags on mines", .tags(.entity), arguments: MinesweeperDifficulty.allCases)
    func winningGame(difficulty: MinesweeperDifficulty) throws {
        var game = makeGame(difficulty)
        game.reveal(at: 0)
        let last = try #require(game.cells.first { !$0.isMine && !$0.isRevealed })
        game.toggleFlag(at: last.id)
        for cell in game.cells where !cell.isMine { game.reveal(at: cell.id) }
        #expect(game.state == .playing)
        game.toggleFlag(at: last.id)
        game.reveal(at: last.id)
        #expect(game.state == .won && game.flagCount == 0)
        let cells = game.cells
        for id in game.cells.indices { game.reveal(at: id); game.toggleFlag(at: id) }
        #expect(game.cells == cells)
    }

    @Test("Invalid coordinates leave the board unchanged", .tags(.entity), arguments: MinesweeperDifficulty.allCases)
    func invalidCoordinates(difficulty: MinesweeperDifficulty) {
        var game = makeGame(difficulty)
        let cells = game.cells
        for id in [-1, game.cells.count, game.cells.count + 10] { game.reveal(at: id); game.toggleFlag(at: id) }
        #expect(game.cells == cells && game.state == .ready)
    }
}
