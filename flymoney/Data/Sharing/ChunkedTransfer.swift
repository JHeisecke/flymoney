//
//  ChunkedTransfer.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-10-30.
//

import Foundation

struct ChunkedTransfer {
	static let headerSize = 5
	static let maximumPayloadSize = 1_048_576
	static let overhead = 35  // seq + inner header + nonce + authentication tag
	static func chunks(of payload: Data, mtu: Int) throws -> [Data] {
		guard mtu > overhead else { throw BLETransferError.capacity }
		guard !payload.isEmpty, payload.count <= maximumPayloadSize else { throw BLETransferError.size }
		let body = mtu - overhead
		let count = (payload.count + body - 1) / body
		guard count <= Int(UInt16.max) else { throw BLETransferError.size }
		return (0..<count).map { index in
			var frame = BLEFrameCodec.word(UInt16(index))
			frame.append(BLEFrameCodec.word(UInt16(count)))
			frame.append(index == count - 1 ? 1 : 0)
			frame.append(payload.subdata(in: (index * body)..<min(payload.count, (index + 1) * body)))
			return frame
		}
	}
	final class Reassembler {
		private var slots: [UInt16: Data] = [:]
		private var bytes = 0
		private(set) var total: UInt16?
		private(set) var receivedLast = false
		private var finished = false
		var receivedCount: Int { slots.count }
		func expect(total value: UInt16) throws {
			guard value > 0, total == nil || total == value else { throw ChunkError.invalidFrame }
			total = value
		}
		func ingest(decryptedFrame frame: Data) throws -> Result {
			guard frame.count >= Self.minimumFrameSize else { throw ChunkError.shortFrame }
			guard !finished else { throw ChunkError.invalidFrame }
			let seq = try BLEFrameCodec.readWord(frame)
			let count = try BLEFrameCodec.readWord(Data(frame.dropFirst(2)))
			let flag = frame[frame.startIndex + 4]
			guard count > 0, seq < count, flag == (seq == count - 1 ? 1 : 0) else {
				throw ChunkError.invalidFrame
			}
			try expect(total: count)
			let body = Data(frame.dropFirst(5))
			if let old = slots[seq] {
				guard old == body else { throw ChunkError.invalidFrame }
			} else {
				guard bytes + body.count <= ChunkedTransfer.maximumPayloadSize else {
					throw BLETransferError.size
				}
				slots[seq] = body
				bytes += body.count
			}
			if flag == 1 { receivedLast = true }
			if slots.count == Int(count), receivedLast {
				var assembled = Data()
				for index in 0..<count {
					guard let part = slots[index] else { throw ChunkError.invalidFrame }
					assembled.append(part)
				}
				finished = true
				slots.removeAll()
				return .complete(assembled)
			}
			return .partial(progress: Double(slots.count) / Double(count))
		}
		func missingSeqs() -> [UInt16] {
			guard let total, !finished else { return [] }
			return (0..<total).filter { slots[$0] == nil }
		}
		private static let minimumFrameSize = 6
	}
	enum Result {
		case partial(progress: Double)
		case complete(Data)
	}
}

enum ChunkError: Error { case shortFrame, invalidFrame }
