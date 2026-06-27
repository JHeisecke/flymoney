//
//  ChunkedTransferTests.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import Foundation
import Testing
@testable import flymoney

@Suite("ChunkedTransfer", .tags(.persistence))
struct ChunkedTransferTests {

	@Test("chunk count math")
	func chunkCount() {
		let payload = Data(repeating: 0x42, count: 400)
		let chunks = ChunkedTransfer.chunks(of: payload, mtu: 185)
		#expect(chunks.count > 1)
		#expect(chunks.last?[4] == 1)
	}

	@Test("roundtrip in-order")
	func roundTrip() throws {
		let payload = Data(repeating: 0x42, count: 200)
		let chunks = ChunkedTransfer.chunks(of: payload, mtu: 185)
		let reassembler = ChunkedTransfer.Reassembler()
		var result: Data?
		for chunk in chunks {
			switch try reassembler.ingest(decryptedFrame: chunk) {
			case .complete(let data): result = data
			case .partial: break
			}
		}
		#expect(result == payload)
	}

	@Test("roundtrip out-of-order")
	func outOfOrder() throws {
		let payload = Data(repeating: 0x42, count: 200)
		let chunks = ChunkedTransfer.chunks(of: payload, mtu: 185)
		let reassembler = ChunkedTransfer.Reassembler()
		var result: Data?
		for chunk in chunks.reversed() {
			switch try reassembler.ingest(decryptedFrame: chunk) {
			case .complete(let data): result = data
			case .partial: break
			}
		}
		#expect(result == payload)
	}

	@Test("dropped chunk detected")
	func droppedChunk() throws {
		let payload = Data(repeating: 0x42, count: 200)
		let chunks = ChunkedTransfer.chunks(of: payload, mtu: 185)
		guard chunks.count >= 3 else { return }
		let reassembler = ChunkedTransfer.Reassembler()
		for i in 0..<chunks.count where i != 1 {
			_ = try reassembler.ingest(decryptedFrame: chunks[i])
		}
		let missing = reassembler.missingSeqs()
		#expect(missing.contains(1))
	}

	@Test("single chunk")
	func singleChunk() throws {
		let payload = Data(repeating: 0x42, count: 10)
		let chunks = ChunkedTransfer.chunks(of: payload, mtu: 185)
		#expect(chunks.count == 1)
		let reassembler = ChunkedTransfer.Reassembler()
		let result = try reassembler.ingest(decryptedFrame: chunks[0])
		if case .complete(let data) = result {
			#expect(data == payload)
		} else {
			#expect(Bool(false))
		}
	}

	@Test("short frame fails")
	func shortFrame() {
		let reassembler = ChunkedTransfer.Reassembler()
		#expect(throws: ChunkError.shortFrame) {
			_ = try reassembler.ingest(decryptedFrame: Data([0x00, 0x01, 0x02]))
		}
	}
}
