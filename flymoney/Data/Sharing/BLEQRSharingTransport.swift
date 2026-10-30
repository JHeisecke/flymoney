//
//  BLEQRSharingTransport.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-10-30.
//

import Foundation

@MainActor
final class BLEQRSharingTransport: SharingTransport {
	private(set) var qrText: String?
	private let makePeripheral: @MainActor () -> any BLERadio
	private let makeCentral: @MainActor () -> any BLERadio
	private var generation: UUID?
	private var task: Task<Void, Never>?
	private var timer: Task<Void, Never>?
	private var radio: (any BLERadio)?
	private var session: BLETransferSession?
	private var output: AsyncStream<TransferEvent>.Continuation?
	private var scanContinuation: CheckedContinuation<String?, Never>?
	private var pendingScan: String?
	private var waitingForScan = false

	init(
		makePeripheral: @escaping @MainActor () -> any BLERadio = { BLEPeripheralService() },
		makeCentral: @escaping @MainActor () -> any BLERadio = { BLECentralService() }
	) {
		self.makePeripheral = makePeripheral
		self.makeCentral = makeCentral
	}
	func send(_ payload: SharePayload) -> AsyncStream<TransferEvent> { stream(payload) }
	func receive() -> AsyncStream<TransferEvent> { stream(nil) }
	private func stream(_ payload: SharePayload?) -> AsyncStream<TransferEvent> {
		let pair = AsyncStream<TransferEvent>.makeStream()
		let id = UUID()
		pair.continuation.onTermination = { [weak self] _ in
			Task { @MainActor in self?.end(id: id) }
		}
		if Task.isCancelled {
			pair.continuation.finish()
		} else {
			begin(payload, id: id, output: pair.continuation)
		}
		return pair.stream
	}
	private func begin(_ payload: SharePayload?, id: UUID, output: AsyncStream<TransferEvent>.Continuation) {
		guard generation == nil else {
			output.yield(.failed(reason: BLETransferError.busy.localizedDescription))
			output.finish()
			return
		}
		generation = id
		self.output = output
		qrText = nil
		task = Task { [weak self] in
			guard let self, generation == id, !Task.isCancelled else { return }
			do {
				var qr: QRPayload?
				if payload == nil {
					waitingForScan = true
					let text: String?
					if let pendingScan {
						text = pendingScan
						self.pendingScan = nil
					} else {
						text = await withCheckedContinuation { scanContinuation = $0 }
					}
					guard generation == id, let text, !Task.isCancelled else { return }
					waitingForScan = false
					do { qr = try QRHandshake.decode(text) } catch QRError.unsupportedVersion {
						throw BLETransferError.incompatibleVersion
					} catch { throw BLETransferError.invalidMessage }
				}
				guard generation == id, !Task.isCancelled else { return }
				let radio = payload == nil ? makeCentral() : makePeripheral()
				self.radio = radio
				let events = radio.events()
				let session = try BLETransferSession(
					payload: payload, qr: qr,
					send: { data, channel in
						try radio.send(data, on: channel)
					},
					emit: { [weak self] event in
						guard self?.generation == id else { return }
						self?.output?.yield(event)
					})
				self.session = session
				if payload != nil { qrText = try QRHandshake.encode(session.qr) }
				output.yield(.handshaking)
				radio.start(serviceUUID: session.qr.svc)
				timer = Task { [weak self, weak session] in
					while !Task.isCancelled {
						do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
						guard let self, generation == id, let session else { return }
						do { try session.tick() } catch {
							fail(error, id: id)
							return
						}
					}
				}
				for await event in events {
					guard generation == id, !Task.isCancelled else { return }
					try session.handle(event)
					if session.finished {
						end(id: id)
						return
					}
				}
				if generation == id { fail(BLETransferError.disconnected, id: id) }
			} catch { fail(error, id: id) }
		}
	}
	func provideScannedQR(_ text: String) {
		guard generation == nil || waitingForScan else { return }
		if let continuation = scanContinuation {
			scanContinuation = nil
			continuation.resume(returning: text)
		} else {
			pendingScan = text
		}
	}
	func cancel() {
		pendingScan = nil
		guard let id = generation else { return }
		output?.yield(.failed(reason: BLETransferError.cancelled.localizedDescription))
		end(id: id)
	}
	private func fail(_ error: any Error, id: UUID) {
		guard generation == id else { return }
		let message =
			(error as? BLETransferError)?.localizedDescription
			?? BLETransferError.invalidMessage.localizedDescription
		output?.yield(.failed(reason: message))
		end(id: id)
	}
	private func end(id: UUID) {
		guard generation == id else { return }
		generation = nil
		task?.cancel()
		task = nil
		timer?.cancel()
		timer = nil
		radio?.stop()
		radio = nil
		session = nil
		let scan = scanContinuation
		scanContinuation = nil
		scan?.resume(returning: nil)
		pendingScan = nil
		waitingForScan = false
		qrText = nil
		output?.finish()
		output = nil
	}
}
