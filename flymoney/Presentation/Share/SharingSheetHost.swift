//
//  SharingSheetHost.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

struct SharingSheetHost: View {
	let assembly: AppAssembly
	let role: SharingRole
	var includeExpensesInitially = true
	@Environment(\.dismiss) private var dismiss

	@State private var vm: SharingViewModel?

	var body: some View {
		content.onDisappear { vm?.cancel() }
	}

	@ViewBuilder private var content: some View {
		if let vm {
			switch role {
			case .send, .sendBudget:
				ShareExportView(viewModel: vm, onDismiss: { dismiss() })
			case .receive:
				NavigationStack {
					Group {
						if vm.importedSavedBudget != nil {
                            SavedBudgetReceiveView(model: vm, assembly: assembly, onDismiss: { dismiss() })
                        } else if case .awaitingSavedBudget = vm.phase {
                            SavedBudgetReceiveView(model: vm, assembly: assembly, onDismiss: { dismiss() })
                        } else if case .saving = vm.phase {
                            ProgressView().interactiveDismissDisabled()
                        } else if case .awaitingMerge = vm.phase {
							MergeView(viewModel: vm, onDismiss: { dismiss() })
						} else {
							ShareReceiveView(viewModel: vm, onDismiss: { dismiss() })
						}
					}
				}
			}
		} else {
			Color.clear
				.onAppear {
					vm = assembly.makeSharingViewModel(role: role)
					vm?.includesExpenses = includeExpensesInitially
				}
		}
	}
}
