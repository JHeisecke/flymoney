//
//  BLEChannel.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-10-30.
//

import Foundation

enum BLEChannel: String, Sendable {
	case control = "E001"
	case data = "E002"
	case status = "E003"
}
