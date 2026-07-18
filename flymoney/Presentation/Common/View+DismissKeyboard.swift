//
//  View+DismissKeyboard.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

extension View {
	func dismissKeyboardOnTap() -> some View {
		self
			.contentShape(.rect)
			.simultaneousGesture(
				TapGesture().onEnded {
					UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
				}
			)
	}
}
