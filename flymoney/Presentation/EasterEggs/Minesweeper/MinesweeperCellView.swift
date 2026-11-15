//
//  MinesweeperCellView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-14.
//

import SwiftUI

struct MinesweeperCellView: View {
    let cell: MinesweeperCell
    let state: MinesweeperState
    let isDetonated: Bool
    let size: CGFloat
    let label: String
    let hint: String
    let action: () -> Void

    private var showsMine: Bool { state.isFinished && cell.isMine }
    private var isFlat: Bool { cell.isRevealed || showsMine }

    var body: some View {
        Button(action: action) {
            ZStack {
                Rectangle().fill(isDetonated ? Color.red : MinesweeperPalette.panel)
                if showsMine {
                    MinesweeperSymbol(isFlag: false).padding(size * 0.2)
                } else if cell.isFlagged {
                    MinesweeperSymbol(isFlag: true).padding(size * 0.2)
                    if state == .lost {
                        Image(systemName: "xmark").font(.title2.bold()).foregroundStyle(.red)
                    }
                } else if cell.isRevealed, cell.adjacentMines > 0 {
                    Text(cell.adjacentMines, format: .number)
                        .font(.system(.title2, design: .monospaced, weight: .bold))
                        .foregroundStyle(MinesweeperPalette.number(cell.adjacentMines))
                }
                Rectangle().strokeBorder(MinesweeperPalette.shadow, lineWidth: 0.5)
                if !isFlat {
                    Canvas { context, bounds in
                        var light = Path()
                        light.move(to: CGPoint(x: 1.5, y: bounds.height - 1.5))
                        light.addLine(to: CGPoint(x: 1.5, y: 1.5))
                        light.addLine(to: CGPoint(x: bounds.width - 1.5, y: 1.5))
                        context.stroke(light, with: .color(MinesweeperPalette.highlight), lineWidth: 3)
                        var shade = Path()
                        shade.move(to: CGPoint(x: bounds.width - 1.5, y: 1.5))
                        shade.addLine(to: CGPoint(x: bounds.width - 1.5, y: bounds.height - 1.5))
                        shade.addLine(to: CGPoint(x: 1.5, y: bounds.height - 1.5))
                        context.stroke(shade, with: .color(MinesweeperPalette.shadow), lineWidth: 3)
                    }
                    .accessibilityHidden(true)
                }
                if isDetonated {
                    Rectangle().strokeBorder(.black, lineWidth: 3)
                }
            }
            .frame(width: size, height: size)
            .contentShape(.rect)
        }
        .buttonStyle(.hapticPlain)
        .accessibilityLabel(label)
        .accessibilityHint(state.isFinished ? "" : hint)
        .accessibilityIdentifier("minesweeper.cell.\(cell.id)")
        .disabled(state.isFinished || cell.isRevealed)
    }
}
