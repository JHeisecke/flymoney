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

	var body: some View {
		let vm = assembly.makeSharingViewModel(role: role)
		switch role {
		case .send:
			ShareExportView(viewModel: vm, onDismiss: { dismiss() })
		case .receive:
			ShareReceiveView(viewModel: vm, onDismiss: { dismiss() })
		}
	}
}
