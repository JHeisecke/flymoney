//
//  MinesweeperSymbol.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-14.
//

import SwiftUI

// Original vector artwork, drawn locally without external bitmap resources.
struct MinesweeperSymbol: View {
    let isFlag: Bool

    var body: some View {
        Canvas { context, size in
            let unit = min(size.width, size.height) / 16
            if isFlag {
                var pole = Path()
                pole.addRect(CGRect(x: 8 * unit, y: 3 * unit, width: unit, height: 10 * unit))
                pole.addRect(CGRect(x: 5 * unit, y: 12 * unit, width: 7 * unit, height: 2 * unit))
                context.fill(pole, with: .color(.black))
                var flag = Path()
                flag.move(to: CGPoint(x: 8 * unit, y: 2 * unit))
                flag.addLine(to: CGPoint(x: 2 * unit, y: 5 * unit))
                flag.addLine(to: CGPoint(x: 8 * unit, y: 8 * unit))
                flag.closeSubpath()
                context.fill(flag, with: .color(.red))
            } else {
                let center = CGPoint(x: 8 * unit, y: 8 * unit)
                for offset in 0..<4 {
                    let angle = Double(offset) * .pi / 4
                    let dx = cos(angle) * 7 * unit
                    let dy = sin(angle) * 7 * unit
                    var spike = Path()
                    spike.move(to: CGPoint(x: center.x - dx, y: center.y - dy))
                    spike.addLine(to: CGPoint(x: center.x + dx, y: center.y + dy))
                    context.stroke(spike, with: .color(.black), lineWidth: unit)
                }
                context.fill(Path(ellipseIn: CGRect(x: 3 * unit, y: 3 * unit, width: 10 * unit, height: 10 * unit)),
                    with: .color(.black))
                context.fill(Path(CGRect(x: 5 * unit, y: 5 * unit, width: 2 * unit, height: 2 * unit)),
                    with: .color(.white))
            }
        }
        .accessibilityHidden(true)
    }
}
