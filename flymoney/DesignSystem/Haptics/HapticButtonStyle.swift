//
//  HapticButtonStyle.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-30.
//

import SwiftUI

struct HapticButtonStyle: ButtonStyle {
	@Environment(\.haptics) private var haptics

	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.onChange(of: configuration.isPressed) { _, pressed in
				if pressed { haptics.tap() }
			}
	}
}

extension ButtonStyle where Self == HapticButtonStyle {
	static var hapticPlain: HapticButtonStyle { .init() }
}
