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
	@Environment(\.dismiss) private var dismiss

	@State private var vm: SharingViewModel?

	var body: some View {
		if let vm {
			switch role {
			case .send:
				ShareExportView(viewModel: vm, onDismiss: { dismiss() })
			case .receive:
				NavigationStack {
					Group {
						if case .awaitingMerge = vm.phase {
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
				}
		}
	}
}
