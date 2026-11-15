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
    private func makeGame() -> MinesweeperGame {
        var generator = MinesweeperTestGenerator()
        return MinesweeperGame(using: &generator)
    }

    @Test("Every possible first reveal is safe and places exactly ten mines", .tags(.entity), arguments: 0..<64)
    func safeFirstReveal(id: Int) {
        var game = makeGame()
        #expect(game.cells.allSatisfy { !$0.isMine && !$0.isRevealed })
        game.reveal(at: id)
        #expect(!game.cells[id].isMine && game.cells[id].isRevealed)
        #expect(game.cells.filter(\.isMine).count == 10)
        #expect(game.state != .lost)
    }

    @Test("Corner, edge and middle counts do not wrap across rows", .tags(.entity))
    func neighborCounts() {
        var game = makeGame()
        game.reveal(at: 0)
        for (id, neighbors) in [(0, [1, 8, 9]), (7, [6, 14, 15]),
            (1, [0, 2, 8, 9, 10]), (9, [0, 1, 2, 8, 10, 16, 17, 18]),
            (63, [54, 55, 62])] {
            #expect(game.cells[id].adjacentMines == neighbors.filter { game.cells[$0].isMine }.count)
        }
    }

    @Test("Flags do not start the game, block reveals and cannot exceed the mine count", .tags(.entity))
    func flagsBeforeFirstReveal() {
        var game = makeGame()
        for id in 0..<11 { game.toggleFlag(at: id) }
        #expect(game.flagCount == 10 && game.remainingFlags == 0)
        #expect(!game.cells[10].isFlagged && game.state == .ready)
        game.reveal(at: 0)
        #expect(game.state == .ready && !game.cells[0].isRevealed)
        game.toggleFlag(at: 0)
        game.reveal(at: 0)
        #expect(!game.cells[0].isMine && game.cells[0].isRevealed)
        game.toggleFlag(at: 0)
        #expect(!game.cells[0].isFlagged)
    }

    @Test("Revealing an empty region exposes its numbered border but preserves flags", .tags(.entity))
    func emptyRegion() throws {
        var game = makeGame()
        game.reveal(at: 0)
        let empty = try #require(game.cells.first { !$0.isMine && !$0.isRevealed && $0.adjacentMines == 0 })
        let flag = try #require(game.cells.first {
            !$0.isMine && !$0.isRevealed && $0.id != empty.id &&
            abs($0.id / 8 - empty.id / 8) <= 1 && abs($0.id % 8 - empty.id % 8) <= 1
        })
        game.toggleFlag(at: flag.id)
        game.reveal(at: empty.id)
        #expect(game.cells[empty.id].isRevealed)
        #expect(!game.cells[flag.id].isRevealed && game.cells[flag.id].isFlagged)
        for cell in game.cells where cell.isRevealed && cell.adjacentMines == 0 {
            for adjacent in game.cells where abs(adjacent.id / 8 - cell.id / 8) <= 1 &&
                abs(adjacent.id % 8 - cell.id % 8) <= 1 && !adjacent.isFlagged {
                #expect(adjacent.isRevealed && !adjacent.isMine)
            }
        }
    }

    @Test("Finding a mine ends the game and freezes further moves", .tags(.entity))
    func losingGame() throws {
        var game = makeGame()
        game.reveal(at: 0)
        let mine = try #require(game.cells.first { $0.isMine })
        game.reveal(at: mine.id)
        #expect(game.state == .lost && game.detonatedCellID == mine.id)
        let cells = game.cells
        for id in 0..<64 { game.reveal(at: id); game.toggleFlag(at: id) }
        #expect(game.cells == cells)
    }

    @Test("All safe cells must be revealed to win, without requiring flags on mines", .tags(.entity))
    func winningGame() throws {
        var game = makeGame()
        game.reveal(at: 0)
        let last = try #require(game.cells.first { !$0.isMine && !$0.isRevealed })
        game.toggleFlag(at: last.id)
        for cell in game.cells where !cell.isMine { game.reveal(at: cell.id) }
        #expect(game.state == .playing)
        game.toggleFlag(at: last.id)
        game.reveal(at: last.id)
        #expect(game.state == .won && game.flagCount == 0)
        let cells = game.cells
        for id in 0..<64 { game.reveal(at: id); game.toggleFlag(at: id) }
        #expect(game.cells == cells)
    }

    @Test("Invalid coordinates leave the board unchanged", .tags(.entity))
    func invalidCoordinates() {
        var game = makeGame()
        let cells = game.cells
        for id in [-1, 64, 100] { game.reveal(at: id); game.toggleFlag(at: id) }
        #expect(game.cells == cells && game.state == .ready)
    }
}
