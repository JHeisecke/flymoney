//
//  SharingRole.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import Foundation

enum SharingRole: Identifiable, Equatable {
	case send(month: CalendarMonth)
	case receive

	var id: String {
		switch self {
		case .send: return "send"
		case .receive: return "receive"
		}
	}
}
