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
		ZStack {
			VStack(spacing: 0) {
				RoundedRectangle(cornerRadius: Theme.Radius.xxs)
					.fill(onDark ? Color(white: 0.23) : Theme.Colors.borderStrong)
					.frame(width: 38, height: 5)
					.padding(.top, Theme.Spacing.xs)
				Text(title)
					.font(Theme.Typography.title17)
					.foregroundStyle(onDark ? Color.white : Theme.Colors.ink)
					.padding(.top, Theme.Spacing.md)
			}
			HStack {
				Spacer()
				Button(action: onCancel) {
					Text(String(localized: "Cancel"))
						.font(Theme.Typography.body15)
						.foregroundStyle(onDark ? Theme.Colors.inkQuaternary : Theme.Colors.inkQuaternary)
				}
				.buttonStyle(.hapticPlain)
				.padding(.trailing, Theme.Spacing.xxl)
				.padding(.top, Theme.Spacing.sm)
			}
		}
	}
}
