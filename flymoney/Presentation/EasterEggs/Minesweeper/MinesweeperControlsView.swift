//
//  MinesweeperControlsView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-14.
//

import SwiftUI

struct MinesweeperControlsView: View {
    @Bindable var model: MinesweeperViewModel

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Flags left")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.inkSecondary)
                    Text(model.game.remainingFlags, format: .number)
                        .font(.system(.title, design: .monospaced, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.Colors.accent)
                }
                .accessibilityElement(children: .combine)
                Spacer()
                Button { model.requestRestart() } label: {
                    VStack(spacing: Theme.Spacing.xs) {
                        MinesweeperFaceView(state: model.game.state).frame(width: 36, height: 36)
                        Text("New game").font(.caption)
                    }
                    .padding(Theme.Spacing.sm)
                    .contentShape(.rect)
                }
                .buttonStyle(.hapticPlain)
                .accessibilityIdentifier("minesweeper.restart")
            }
            Picker("Action", selection: $model.isFlagging) {
                Label("Reveal", systemImage: "hand.tap").tag(false)
                Label("Flag", systemImage: "flag.fill").tag(true)
            }
            .pickerStyle(.segmented)
            .disabled(model.game.state.isFinished)
            Text("Tap a square to reveal it, or choose Flag to mark it. Scroll the board if needed.")
                .font(.footnote)
                .foregroundStyle(Theme.Colors.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
