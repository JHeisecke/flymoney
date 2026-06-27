//
//  Collection+SafeSubscript.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import Foundation

extension Collection {
	subscript(safe index: Index) -> Element? {
		indices.contains(index) ? self[index] : nil
	}
}
