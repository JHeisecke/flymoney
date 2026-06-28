//
//  ScannerOverlay.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

struct ScannerOverlay: View {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@State private var scanY: CGFloat = 0.1

	var body: some View {
		ZStack {
			Color.clear
			GeometryReader { geo in
				cornerBrackets(in: geo.size)
				if !reduceMotion {
					scanLine(in: geo.size)
				}
			}
		}
		.frame(width: 248, height: 248)
		.clipShape(.rect(cornerRadius: Theme.Radius.xxxl))
		.overlay {
			RoundedRectangle(cornerRadius: Theme.Radius.xxxl)
				.stroke(Theme.Colors.borderSubtle, lineWidth: 1)
		}
	}

	@ViewBuilder
	private func cornerBrackets(in size: CGSize) -> some View {
		ForEach(0..<4) { i in
			cornerPath(i)
				.stroke(Theme.Colors.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
				.frame(width: 34, height: 34)
				.position(cornerPosition(i, in: size))
		}
	}

	private func cornerPath(_ corner: Int) -> Path {
		Path { p in
			switch corner {
			case 0:
				p.move(to: CGPoint(x: 0, y: 34)); p.addLine(to: CGPoint(x: 0, y: 12))
				p.move(to: CGPoint(x: 0, y: 0)); p.addLine(to: CGPoint(x: 12, y: 0))
			case 1:
				p.move(to: CGPoint(x: 34, y: 34)); p.addLine(to: CGPoint(x: 34, y: 12))
				p.move(to: CGPoint(x: 34, y: 0)); p.addLine(to: CGPoint(x: 22, y: 0))
			case 2:
				p.move(to: CGPoint(x: 0, y: 0)); p.addLine(to: CGPoint(x: 0, y: 22))
				p.move(to: CGPoint(x: 0, y: 34)); p.addLine(to: CGPoint(x: 12, y: 34))
			case 3:
				p.move(to: CGPoint(x: 34, y: 0)); p.addLine(to: CGPoint(x: 34, y: 22))
				p.move(to: CGPoint(x: 34, y: 34)); p.addLine(to: CGPoint(x: 22, y: 34))
			default: break
			}
		}
	}

	private func cornerPosition(_ corner: Int, in size: CGSize) -> CGPoint {
		switch corner {
		case 0: CGPoint(x: 17, y: 17)
		case 1: CGPoint(x: size.width - 17, y: 17)
		case 2: CGPoint(x: 17, y: size.height - 17)
		default: CGPoint(x: size.width - 17, y: size.height - 17)
		}
	}

	@ViewBuilder
	private func scanLine(in size: CGSize) -> some View {
		Rectangle()
			.fill(LinearGradient(
				colors: [.clear, Theme.Colors.accent, .clear],
				startPoint: .leading, endPoint: .trailing))
			.frame(height: 2)
			.shadow(color: Theme.Colors.accent, radius: 12)
			.offset(y: scanY * size.height)
			.onAppear {
				withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
					scanY = 0.88
				}
			}
	}
}
