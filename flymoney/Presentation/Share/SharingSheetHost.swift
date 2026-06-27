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

	var body: some View {
		let vm = assembly.makeSharingViewModel(role: role)
		Group {
			switch role {
			case .send:
				NavigationStack {
					ShareExportView(viewModel: vm)
						.navigationTitle(Text(String(localized: "Share Month")))
						.navigationBarTitleDisplayMode(.inline)
						.task { await vm.start() }
				}
			case .receive:
				NavigationStack {
					if case .awaitingMerge = vm.phase {
						MergeView(viewModel: vm)
							.navigationTitle(Text(String(localized: "Share Month")))
							.navigationBarTitleDisplayMode(.inline)
					} else {
						ShareReceiveView(viewModel: vm)
							.navigationTitle(Text(String(localized: "Share Month")))
							.navigationBarTitleDisplayMode(.inline)
					}
				}
			}
		}
	}
}
