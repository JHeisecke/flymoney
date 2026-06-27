//
//  TestModelContainer.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import SwiftData
@testable import flymoney

enum TestSupport {
	static func makeContainer() throws -> ModelContainer {
		try SwiftDataStack.makeInMemoryContainer()
	}
}
