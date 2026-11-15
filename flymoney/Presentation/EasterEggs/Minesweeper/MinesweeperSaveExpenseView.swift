//
//  MinesweeperSaveExpenseView.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-14.
//

import SwiftUI

struct MinesweeperSaveExpenseView: View {
    let model: MinesweeperViewModel
    @Bindable var expenseModel: AddExpenseViewModel

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            if let error = expenseModel.saveError {
                Text(error).foregroundStyle(Theme.Colors.danger)
                    .accessibilityIdentifier("minesweeper.saveError")
            }
            HStack(spacing: Theme.Spacing.md) {
                Button("Try again", action: model.requestRestart)
                    .font(Theme.Typography.body17)
                    .foregroundStyle(Theme.Colors.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(Theme.Colors.card)
                    .clipShape(.rect(cornerRadius: Theme.Radius.lg))
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.Radius.lg)
                            .strokeBorder(Theme.Colors.borderStrong, lineWidth: 1)
                    }
                    .buttonStyle(.hapticPlain)
                    .disabled(expenseModel.isSaving)
                    .accessibilityIdentifier("minesweeper.retry")

                SaveButton(title: "Save expense", isLoading: expenseModel.isSaving,
                    isDisabled: !expenseModel.form.canSave) {
                    Task { await expenseModel.saveMinesweeperExpense() }
                }
                .accessibilityIdentifier("minesweeper.saveExpense")
            }
            Text("Your expense is only saved when you choose Save expense.")
                .font(.footnote)
                .foregroundStyle(Theme.Colors.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.vertical, Theme.Spacing.md)
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
        .background(Theme.Colors.surface)
    }
}
