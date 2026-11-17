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
                    let eye = Path(ellipseIn: CGRect(x: (x - 2.5) * unit, y: 7 * unit,
                        width: 5 * unit, height: 6 * unit))
                    context.fill(eye, with: .color(.white))
                    context.stroke(eye, with: .color(.black), lineWidth: 0.75 * unit)
                    context.fill(Path(ellipseIn: CGRect(x: (x - 0.6) * unit, y: 9 * unit,
                        width: 1.2 * unit, height: 2 * unit)), with: .color(.black))
                } else if state == .won {
                    var dollar = Path()
                    dollar.move(to: CGPoint(x: (x + 2) * unit, y: 6 * unit))
                    dollar.addLine(to: CGPoint(x: (x - 1) * unit, y: 6 * unit))
                    dollar.addLine(to: CGPoint(x: (x - 2) * unit, y: 7 * unit))
                    dollar.addLine(to: CGPoint(x: (x - 2) * unit, y: 8 * unit))
                    dollar.addLine(to: CGPoint(x: (x + 2) * unit, y: 10 * unit))
                    dollar.addLine(to: CGPoint(x: (x + 2) * unit, y: 11 * unit))
                    dollar.addLine(to: CGPoint(x: (x + 1) * unit, y: 12 * unit))
                    dollar.addLine(to: CGPoint(x: (x - 2) * unit, y: 12 * unit))
                    dollar.move(to: CGPoint(x: x * unit, y: 5 * unit))
                    dollar.addLine(to: CGPoint(x: x * unit, y: 13 * unit))
                    context.stroke(dollar, with: .color(.black), lineWidth: unit)
                } else {
                    context.fill(Path(ellipseIn: CGRect(x: (x - 1) * unit, y: 7 * unit,
                        width: 2 * unit, height: 4 * unit)), with: .color(.black))
                }
            }
            if state == .won {
                var smile = Path()
                smile.move(to: CGPoint(x: 6 * unit, y: 15 * unit))
                smile.addLine(to: CGPoint(x: 18 * unit, y: 15 * unit))
                smile.addQuadCurve(to: CGPoint(x: 6 * unit, y: 15 * unit),
                    control: CGPoint(x: 12 * unit, y: 24 * unit))
                smile.closeSubpath()
                context.fill(smile, with: .color(.black))
                let bill = Path(CGRect(x: 11 * unit, y: 17 * unit, width: 5 * unit, height: 6 * unit))
                context.fill(bill, with: .color(Color(red: 0.25, green: 0.65, blue: 0.35)))
                context.stroke(bill, with: .color(.black), lineWidth: 0.75 * unit)
                let billDetail = Path(ellipseIn: CGRect(x: 12.5 * unit, y: 18.5 * unit,
                    width: 2 * unit, height: 3 * unit))
                context.stroke(billDetail, with: .color(Color(red: 0, green: 0.25, blue: 0.1)),
                    lineWidth: 0.6 * unit)
            } else if state == .lost {
                let mouth = Path(ellipseIn: CGRect(x: 9 * unit, y: 14 * unit,
                    width: 6 * unit, height: 8 * unit))
                context.fill(mouth, with: .color(.black))
                for isLeft in [true, false] {
                    let outerX: CGFloat = isLeft ? 2 : 22
                    let innerX: CGFloat = isLeft ? 6 : 18
                    var hand = Path()
                    hand.move(to: CGPoint(x: (isLeft ? 3 : 21) * unit, y: 22 * unit))
                    hand.addLine(to: CGPoint(x: outerX * unit, y: 14 * unit))
                    hand.addQuadCurve(to: CGPoint(x: (isLeft ? 4 : 20) * unit, y: 13 * unit),
                        control: CGPoint(x: (isLeft ? 2 : 22) * unit, y: 11 * unit))
                    hand.addLine(to: CGPoint(x: innerX * unit, y: 17 * unit))
                    hand.addLine(to: CGPoint(x: innerX * unit, y: 22 * unit))
                    hand.closeSubpath()
                    context.fill(hand, with: .color(Color(red: 1, green: 0.79, blue: 0.43)))
                    context.stroke(hand, with: .color(.black), lineWidth: 0.75 * unit)
                }
            } else {
                var mouth = Path()
                mouth.move(to: CGPoint(x: 7 * unit, y: 15 * unit))
                mouth.addQuadCurve(to: CGPoint(x: 17 * unit, y: 15 * unit),
                    control: CGPoint(x: 12 * unit, y: 22 * unit))
                context.stroke(mouth, with: .color(.black), lineWidth: unit)
            }
        }
        .accessibilityHidden(true)
    }
}
