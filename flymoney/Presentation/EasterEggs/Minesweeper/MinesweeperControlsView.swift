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
            Menu {
                ForEach(MinesweeperDifficulty.allCases) { difficulty in
                    Button { model.requestDifficulty(difficulty) } label: {
                        HStack {
                            Text(verbatim: model.difficultyName(difficulty))
                            if difficulty == model.game.difficulty { Image(systemName: "checkmark") }
                        }
                    }
                }
            } label: {
                HStack {
                    Text("Difficulty")
                    Spacer()
                    Text(verbatim: model.difficultyName(model.game.difficulty))
                    Image(systemName: "chevron.up.chevron.down")
                        .accessibilityHidden(true)
                }
                .padding(Theme.Spacing.md)
                .frame(minHeight: 44)
                .background(Theme.Colors.segmentedTrack, in: .rect(cornerRadius: Theme.Radius.sm))
                .contentShape(.rect)
            }
            .accessibilityIdentifier("minesweeper.difficulty")
            Text("\(model.game.columns) × \(model.game.rows) · \(model.game.mineCount) mines")
                .font(.caption)
                .foregroundStyle(Theme.Colors.inkSecondary)
            HStack(spacing: Theme.Spacing.xs) {
                Button { model.isFlagging = false } label: {
                    Label("Reveal", systemImage: "magnifyingglass")
                        .font(.body.weight(model.isFlagging ? .regular : .semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(model.isFlagging ? Color.clear : Theme.Colors.segmentedThumb,
                            in: .rect(cornerRadius: Theme.Radius.xs))
                        .contentShape(.rect)
                }
                .accessibilityAddTraits(model.isFlagging ? [] : .isSelected)
                .accessibilityIdentifier("minesweeper.reveal")
                Button { model.isFlagging = true } label: {
                    Label {
                        Text("Flag")
                    } icon: {
                        Image(.minesweeperMarker)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                    }
                    .font(.body.weight(model.isFlagging ? .semibold : .regular))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(model.isFlagging ? Theme.Colors.segmentedThumb : Color.clear,
                        in: .rect(cornerRadius: Theme.Radius.xs))
                    .contentShape(.rect)
                }
                .accessibilityAddTraits(model.isFlagging ? .isSelected : [])
                .accessibilityIdentifier("minesweeper.flag")
            }
            .labelStyle(.titleAndIcon)
            .buttonStyle(.hapticPlain)
            .foregroundStyle(Theme.Colors.ink)
            .padding(Theme.Spacing.xs)
            .background(Theme.Colors.segmentedTrack, in: .rect(cornerRadius: Theme.Radius.sm))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Action")
            .disabled(model.game.state.isFinished)
            Text("Tap a square to reveal it, or choose Flag to mark it. Scroll the board if needed.")
                .font(.footnote)
                .foregroundStyle(Theme.Colors.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
