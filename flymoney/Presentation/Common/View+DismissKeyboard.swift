//
//  View+DismissKeyboard.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import SwiftUI

extension View {
	func dismissKeyboardOnTap() -> some View {
		background(Color.clear.contentShape(.rect).onTapGesture {
			UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
		})
	}
}
