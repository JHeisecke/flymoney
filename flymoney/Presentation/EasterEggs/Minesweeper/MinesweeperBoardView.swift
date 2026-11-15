//
//  MinesweeperBoardView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-14.
//

import SwiftUI

struct MinesweeperBoardView: View {
    let model: MinesweeperViewModel
    @ScaledMetric(relativeTo: .body) private var cellSize = 44

    private var cellSide: CGFloat { max(44, cellSize) }

    var body: some View {
        ScrollView(.horizontal) {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(cellSide), spacing: 0),
                count: MinesweeperGame.columns), spacing: 0) {
                ForEach(model.game.cells) { cell in
                    MinesweeperCellView(cell: cell, state: model.game.state,
                        isDetonated: model.game.detonatedCellID == cell.id, size: cellSide,
                        label: model.cellLabel(cell), hint: model.cellHint) {
                            model.play(at: cell.id)
                        }
                }
            }
            .frame(width: cellSide * CGFloat(MinesweeperGame.columns))
            .padding(Theme.Spacing.sm)
            .background(MinesweeperPalette.shadow)
            .overlay { Rectangle().strokeBorder(MinesweeperPalette.panel, lineWidth: 3) }
        }
        .accessibilityLabel("Minefield")
    }
}
