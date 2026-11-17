//
//  MinesweeperSymbol.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-14.
//

import SwiftUI

// Original retro artwork, drawn locally without external bitmap resources.
struct MinesweeperSymbol: View {
    let isFlag: Bool

    var body: some View {
        Group {
            if isFlag {
                Image(.minesweeperMarker)
                    .resizable()
                    .scaledToFit()
            } else {
                Canvas { context, size in
                    let pixel = min(size.width / 24, size.height / 16)
                    let origin = CGPoint(x: (size.width - 24 * pixel) / 2,
                        y: (size.height - 16 * pixel) / 2)
                    for (row, pixels) in Self.flyingMoneyPixels.enumerated() {
                        for (column, symbol) in pixels.enumerated() {
                            let color: Color
                            switch symbol {
                            case "#": color = .black
                            case "W": color = .white
                            case "S": color = Color(white: 0.7)
                            case "g": color = Color(red: 0.25, green: 0.65, blue: 0.35)
                            case "h": color = Color(red: 0.7, green: 0.9, blue: 0.55)
                            case "D": color = Color(red: 0, green: 0.25, blue: 0.1)
                            default: continue
                            }
                            let rect = CGRect(x: origin.x + CGFloat(column) * pixel,
                                y: origin.y + CGFloat(row) * pixel, width: pixel, height: pixel)
                            context.fill(Path(rect), with: .color(color), style: FillStyle(antialiased: false))
                        }
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    private static let flyingMoneyPixels = [
        "........................",
        "........................",
        "##....................##",
        "#W##................##W#",
        "#WWW##............##WWW#",
        "#WWSWW#..........#WWSWW#",
        "#WSWWW#..........#WWWSW#",
        ".#WWS##############SWW#.",
        "..#WW#hggggDgggggh#WW#..",
        "...#W#ggggDDDggggg#W#...",
        "....##ggggDDgggggg##....",
        ".....#ggggDDDggggg#.....",
        ".....#gggggDDggggg#.....",
        ".....#hgggDDDggggh#.....",
        ".....##############.....",
        "........................",
    ]
}
