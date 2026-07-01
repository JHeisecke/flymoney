//
//  EnvironmentValues+Haptics.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-30.
//

import SwiftUI

extension EnvironmentValues {
	@Entry var haptics: any HapticsFeedback = NoopHapticsFeedback()
}
