//
//  MinesweeperView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-14.
//

import SwiftUI

struct MinesweeperView: View {
    @State private var model: MinesweeperViewModel
    @Bindable var expenseModel: AddExpenseViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.haptics) private var haptics
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(model: MinesweeperViewModel, expenseModel: AddExpenseViewModel) {
        _model = State(initialValue: model)
        self.expenseModel = expenseModel
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text(verbatim: model.statusTitle)
                            .font(.custom("Sora", size: 27, relativeTo: .title).bold())
                            .accessibilityAddTraits(.isHeader)
                        Text(verbatim: model.statusMessage)
                            .foregroundStyle(Theme.Colors.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    MinesweeperControlsView(model: model)
                        .padding(Theme.Spacing.lg)
                        .background(Theme.Colors.card)
                        .clipShape(.rect(cornerRadius: Theme.Radius.lg))
                    MinesweeperBoardView(model: model)
                    if dynamicTypeSize.isAccessibilitySize {
                        MinesweeperSaveExpenseView(model: model, expenseModel: expenseModel)
                    }
                }
                .padding(Theme.Spacing.xl)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !dynamicTypeSize.isAccessibilitySize {
                    MinesweeperSaveExpenseView(model: model, expenseModel: expenseModel)
                }
            }
            .font(.custom("Sora", size: 16, relativeTo: .body))
            .foregroundStyle(Theme.Colors.ink)
            .background(Theme.Colors.surface)
            .navigationTitle("Minesweeper")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    SheetCloseButton { dismiss() }
                }
            }
            .disabled(expenseModel.isSaving)
            .confirmationDialog("Start a new game?", isPresented: $model.confirmRestart,
                titleVisibility: .visible) {
                Button("New game", role: .destructive) { model.restart() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Your current board will be cleared.")
            }
        }
        .interactiveDismissDisabled(expenseModel.isSaving)
        .onChange(of: model.game.state) { _, state in
            guard state.isFinished else { return }
            if state == .won { haptics.success() }
            else { haptics.error() }
            AccessibilityNotification.Announcement(model.statusTitle).post()
        }
        .onChange(of: expenseModel.saveError) { _, error in
            if let error {
                haptics.error()
                AccessibilityNotification.Announcement(error).post()
            }
        }
    }
}
