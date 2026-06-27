//
//  SwiftDataStack.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-26.
//

import Foundation
import SwiftData

enum SwiftDataStack {
	static func makeContainer() throws -> ModelContainer {
		let config = ModelConfiguration(schema: ModelSchema.schema, isStoredInMemoryOnly: false)
		return try ModelContainer(for: ModelSchema.schema, configurations: config)
	}

	static func makeInMemoryContainer() throws -> ModelContainer {
		let config = ModelConfiguration(schema: ModelSchema.schema, isStoredInMemoryOnly: true)
		return try ModelContainer(for: ModelSchema.schema, configurations: config)
	}
}
