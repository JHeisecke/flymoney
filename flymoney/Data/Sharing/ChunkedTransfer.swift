//
//  ChunkedTransfer.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import Foundation

struct ChunkedTransfer {
	static let headerSize = 5

	static func chunks(of payload: Data, mtu: Int) -> [Data] {
		let overhead = headerSize + 16 + 12
		let body = max(1, mtu - overhead)
		var out: [Data] = []
		var index = 0
		let totalChunks = UInt16((payload.count + body - 1) / max(body, 1))
		var seq: UInt16 = 0
		while index < payload.count {
			let end = min(index + body, payload.count)
			var frame = Data()
			frame.append(UInt8(seq >> 8)); frame.append(UInt8(seq & 0xFF))
			frame.append(UInt8(totalChunks >> 8)); frame.append(UInt8(totalChunks & 0xFF))
			frame.append(end == payload.count ? 1 : 0)
			frame.append(payload.subdata(in: index..<end))
			out.append(frame)
			index = end
			seq &+= 1
		}
		return out
	}

	final class Reassembler {
		private var slots: [UInt16: Data] = [:]
		private(set) var total: UInt16?
		private(set) var receivedLast = false

		func ingest(decryptedFrame frame: Data) throws -> Result {
			guard frame.count >= ChunkedTransfer.headerSize else { throw ChunkError.shortFrame }
			let bytes = [UInt8](frame)
			let seq = (UInt16(bytes[0]) << 8) | UInt16(bytes[1])
			let tot = (UInt16(bytes[2]) << 8) | UInt16(bytes[3])
			let isLast = bytes[4] == 1
			let body = frame.subdata(in: ChunkedTransfer.headerSize..<frame.count)
			slots[seq] = body
			total = tot
			if isLast { receivedLast = true }
			if let total, slots.count == Int(total), receivedLast {
				let assembled = (0..<tot).reduce(into: Data()) { acc, i in
					acc.append(slots[i] ?? Data())
				}
				slots.removeAll()
				return .complete(assembled)
			}
			return .partial(progress: Double(slots.count) / Double(total ?? 1))
		}

		func missingSeqs() -> [UInt16] {
			guard let total else { return [] }
			return (0..<total).filter { slots[$0] == nil }
		}
	}

	enum Result { case partial(progress: Double), complete(Data) }
}

enum ChunkError: Error { case shortFrame }
