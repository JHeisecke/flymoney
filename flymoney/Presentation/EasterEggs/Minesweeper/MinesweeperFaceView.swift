//
//  MinesweeperFaceView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-14.
//

import SwiftUI

struct MinesweeperFaceView: View {
    let state: MinesweeperState

    var body: some View {
        Canvas { context, size in
            let unit = min(size.width, size.height) / 24
            let face = Path(ellipseIn: CGRect(x: unit, y: unit, width: 22 * unit, height: 22 * unit))
            context.fill(face, with: .color(.yellow))
            context.stroke(face, with: .color(.black), lineWidth: unit)
            for x in [8.0, 16.0] {
                if state == .lost {
                    var eye = Path()
                    eye.move(to: CGPoint(x: (x - 2) * unit, y: 7 * unit))
                    eye.addLine(to: CGPoint(x: (x + 2) * unit, y: 11 * unit))
                    eye.move(to: CGPoint(x: (x + 2) * unit, y: 7 * unit))
                    eye.addLine(to: CGPoint(x: (x - 2) * unit, y: 11 * unit))
                    context.stroke(eye, with: .color(.black), lineWidth: unit)
                } else {
                    context.fill(Path(ellipseIn: CGRect(x: (x - 1) * unit, y: 7 * unit,
                        width: 2 * unit, height: 4 * unit)), with: .color(.black))
                }
            }
            var mouth = Path()
            mouth.move(to: CGPoint(x: 7 * unit, y: 15 * unit))
            mouth.addQuadCurve(to: CGPoint(x: 17 * unit, y: 15 * unit),
                control: CGPoint(x: 12 * unit, y: (state == .lost ? 11 : 22) * unit))
            context.stroke(mouth, with: .color(.black), lineWidth: unit)
            if state == .won {
                context.fill(Path(CGRect(x: 5 * unit, y: 7 * unit, width: 14 * unit, height: 4 * unit)),
                    with: .color(.black))
            }
        }
        .accessibilityHidden(true)
    }
}
