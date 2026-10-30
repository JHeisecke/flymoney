//
//  BLERadioEvent.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-10-30.
//

import Foundation

enum BLERadioEvent: Sendable {
	case ready(capacity: Int)
	case message(Data, BLEChannel)
	case sent(Data, BLEChannel)
	case failed(String)
}
