//
//  ShareSheetHeader.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

struct ShareSheetHeader: View {
	let title: LocalizedStringResource
	let onCancel: () -> Void
	var onDark: Bool = false

	var body: some View {
		VStack(spacing: 0) {
			RoundedRectangle(cornerRadius: Theme.Radius.xxs)
				.fill(onDark ? Color(white: 0.23) : Theme.Colors.borderStrong)
				.frame(width: 38, height: 5)
				.padding(.top, Theme.Spacing.xs)
				.accessibilityHidden(true)
			HStack(spacing: 0) {
				Text(title)
					.font(Theme.Typography.title17)
					.foregroundStyle(onDark ? Theme.Colors.accentOnDark : Theme.Colors.ink)
					.multilineTextAlignment(.center)
					.fixedSize(horizontal: false, vertical: true)
					.frame(maxWidth: .infinity)
					.padding(.leading, 44)
				SheetCloseButton(action: onCancel)
			}
			.padding(.horizontal, Theme.Spacing.md)
		}
	}
}
