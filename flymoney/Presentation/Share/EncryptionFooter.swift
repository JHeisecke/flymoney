//
//  EncryptionFooter.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

struct EncryptionFooter: View {
	var body: some View {
		HStack(spacing: Theme.Spacing.xs) {
			Image(systemName: "lock.fill")
				.font(Theme.Typography.caption12)
			Text(String(localized: "End-to-end encrypted · X25519 · ChaChaPoly"))
				.font(Theme.Typography.body13)
		}
		.foregroundStyle(Theme.Colors.inkQuaternary)
	}
}
