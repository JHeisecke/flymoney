//
//  SwiftDataTitleAliasRepository.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-08-05.
//

import Foundation
import SwiftData

actor SwiftDataTitleAliasRepository: TitleAliasRepository, ModelActor {
	nonisolated let modelContainer: ModelContainer
	nonisolated let modelExecutor: any ModelExecutor

	init(modelContainer: ModelContainer) {
		self.modelContainer = modelContainer
		self.modelExecutor = DefaultSerialModelExecutor(modelContext: ModelContext(modelContainer))
	}

	private var context: ModelContext { modelContext }

	func alias(forNormalizedDetail detail: String) async throws -> TitleAlias? {
		let descriptor = FetchDescriptor<TitleAliasModel>(predicate: #Predicate { $0.normalizedDetail == detail })
		return try context.fetch(descriptor).first?.toEntity()
	}

	func aliases(forNormalizedDetails details: [String]) async throws -> [String: TitleAlias] {
		let descriptor = FetchDescriptor<TitleAliasModel>(predicate: #Predicate { details.contains($0.normalizedDetail) })
		let rows = try context.fetch(descriptor)
		return Dictionary(uniqueKeysWithValues: rows.map { ($0.normalizedDetail, $0.toEntity()) })
	}

	/// Unique on `normalizedDetail` — an existing row is re-pointed to the new
	/// `titleID` rather than duplicated.
	func upsert(_ alias: TitleAlias) async throws {
		let detail = alias.normalizedDetail
		let existing = try context.fetch(
			FetchDescriptor<TitleAliasModel>(predicate: #Predicate { $0.normalizedDetail == detail })
		).first
		if let existing {
			existing.titleID = alias.titleID
		} else {
			context.insert(TitleAliasModel(
				id: alias.id, normalizedDetail: alias.normalizedDetail,
				titleID: alias.titleID, createdAt: alias.createdAt
			))
		}
		try context.save()
	}

	func delete(id: UUID) async throws {
		let descriptor = FetchDescriptor<TitleAliasModel>(predicate: #Predicate { $0.id == id })
		for model in try context.fetch(descriptor) {
			context.delete(model)
		}
		try context.save()
	}

	func deleteAll(forTitleID titleID: UUID) async throws {
		let descriptor = FetchDescriptor<TitleAliasModel>(predicate: #Predicate { $0.titleID == titleID })
		for model in try context.fetch(descriptor) {
			context.delete(model)
		}
		try context.save()
	}
}

extension TitleAliasModel {
	func toEntity() -> TitleAlias {
		TitleAlias(id: id, normalizedDetail: normalizedDetail, titleID: titleID, createdAt: createdAt)
	}
}
