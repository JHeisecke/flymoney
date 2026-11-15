//
//  MinesweeperGame.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-14.
//

struct MinesweeperGame {
    static let columns = 8
    static let rows = 8
    static let mineCount = 10

    private(set) var cells: [MinesweeperCell]
    private(set) var state: MinesweeperState = .ready
    private(set) var detonatedCellID: Int?
    private let mineOrder: [Int]

    init() {
        var generator = SystemRandomNumberGenerator()
        self.init(using: &generator)
    }

    init(using generator: inout some RandomNumberGenerator) {
        cells = (0..<(Self.rows * Self.columns)).map { MinesweeperCell(id: $0) }
        mineOrder = cells.map(\.id).shuffled(using: &generator)
    }

    var flagCount: Int { cells.filter(\.isFlagged).count }
    var remainingFlags: Int { Self.mineCount - flagCount }

    mutating func toggleFlag(at id: Int) {
        guard cells.indices.contains(id), !state.isFinished, !cells[id].isRevealed else { return }
        guard cells[id].isFlagged || remainingFlags > 0 else { return }
        cells[id].isFlagged.toggle()
    }

    mutating func reveal(at id: Int) {
        guard cells.indices.contains(id), !state.isFinished,
              !cells[id].isRevealed, !cells[id].isFlagged else { return }
        if state == .ready { placeMines(excluding: id) }
        if cells[id].isMine {
            cells[id].isRevealed = true
            detonatedCellID = id
            state = .lost
            return
        }

        var pending = [id]
        while let next = pending.popLast() {
            guard !cells[next].isRevealed, !cells[next].isFlagged, !cells[next].isMine else { continue }
            cells[next].isRevealed = true
            if cells[next].adjacentMines == 0 {
                pending.append(contentsOf: neighbors(of: next))
            }
        }
        if cells.allSatisfy({ $0.isMine || $0.isRevealed }) { state = .won }
    }

    private mutating func placeMines(excluding firstCell: Int) {
        for id in mineOrder.lazy.filter({ $0 != firstCell }).prefix(Self.mineCount) {
            cells[id].isMine = true
        }
        for id in cells.indices {
            cells[id].adjacentMines = neighbors(of: id).filter { cells[$0].isMine }.count
        }
        state = .playing
    }

    private func neighbors(of id: Int) -> [Int] {
        let row = id / Self.columns
        let column = id % Self.columns
        return (-1...1).flatMap { rowOffset in
            (-1...1).compactMap { columnOffset in
                let nextRow = row + rowOffset
                let nextColumn = column + columnOffset
                guard rowOffset != 0 || columnOffset != 0,
                      (0..<Self.rows).contains(nextRow),
                      (0..<Self.columns).contains(nextColumn) else { return nil }
                return nextRow * Self.columns + nextColumn
            }
        }
    }
}
