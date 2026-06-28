//
//  StatusBadge.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

enum StatusBadgeStyle { case match, similar, newItem }

struct StatusBadge: View {
	let style: StatusBadgeStyle

	var body: some View {
		Text(label)
			.font(Theme.Typography.micro10)
			.textCase(.uppercase)
			.tracking(0.7)
			.padding(.horizontal, 7)
			.padding(.vertical, 4)
			.background(bgColor)
			.foregroundStyle(fgColor)
			.clipShape(.rect(cornerRadius: Theme.Radius.xs))
	}

	private var label: LocalizedStringResource {
		switch style {
		case .match: "MATCH"
		case .similar: "SIMILAR"
		case .newItem: "NEW"
		}
	}

	private var fgColor: Color {
		switch style {
		case .match: Theme.Colors.success
		case .similar: Theme.Colors.warning
		case .newItem: Theme.Colors.inkTertiary
		}
	}

	private var bgColor: Color {
		switch style {
		case .match: Theme.Colors.successTint
		case .similar: Theme.Colors.warningTint
		case .newItem: Theme.Colors.neutralTint
		}
	}
}
