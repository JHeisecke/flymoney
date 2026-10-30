//
//  BLEPeripheralService.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-10-30.
//

import CoreBluetooth
import Foundation

@MainActor
final class BLEPeripheralService: NSObject, CBPeripheralManagerDelegate, BLERadio {
	private var manager: CBPeripheralManager?
	private var serviceUUID: CBUUID?
	private var characteristics: [BLEChannel: CBMutableCharacteristic] = [:]
	private var continuation: AsyncStream<BLERadioEvent>.Continuation?
	private var peer: CBCentral?
	private var subscriptions: Set<String> = []
	private var queue = BLENotificationQueue()
	private var active = false
	private var addedService = false
	private var ready = false

	func events() -> AsyncStream<BLERadioEvent> {
		let pair = AsyncStream<BLERadioEvent>.makeStream()
		continuation = pair.continuation
		active = true
		manager = CBPeripheralManager(delegate: self, queue: .main)
		return pair.stream
	}
	func start(serviceUUID: String) {
		self.serviceUUID = CBUUID(string: serviceUUID)
		addServiceIfReady()
	}
	private func addServiceIfReady() {
		guard active, let manager, manager.state == .poweredOn, let serviceUUID, !addedService else { return }
		addedService = true
		let service = CBMutableService(type: serviceUUID, primary: true)
		for channel in [BLEChannel.control, .data, .status] {
			characteristics[channel] = CBMutableCharacteristic(
				type: CBUUID(string: channel.rawValue),
				properties: channel == .control ? [.write] : [.notify], value: nil,
				permissions: channel == .control ? [.writeable] : [.readable])
		}
		service.characteristics = [.control, .data, .status].compactMap { characteristics[$0] }
		manager.add(service)
	}
	func send(_ data: Data, on channel: BLEChannel) throws {
		guard active, ready, let peer, channel != .control else { throw BLETransferError.disconnected }
		guard data.count <= peer.maximumUpdateValueLength else { throw BLETransferError.capacity }
		queue.append(data, on: channel)
		drain()
	}
	private func drain() {
		guard active, let manager, let peer else { return }
		let chars = characteristics
		let output = continuation
		queue.drain(
			accept: { data, channel in
				guard let characteristic = chars[channel] else { return false }
				return manager.updateValue(data, for: characteristic, onSubscribedCentrals: [peer])
			}, sent: { data, channel in output?.yield(.sent(data, channel)) })
	}
	func stop() {
		active = false
		manager?.stopAdvertising()
		if manager?.state == .poweredOn { manager?.removeAllServices() }
		manager?.delegate = nil
		manager = nil
		peer = nil
		serviceUUID = nil
		characteristics.removeAll()
		subscriptions.removeAll()
		queue.removeAll()
		addedService = false
		ready = false
		continuation?.finish()
		continuation = nil
	}
	private func fail() {
		continuation?.yield(
			.failed(String(localized: "Bluetooth is unavailable. Check Settings and try again.")))
	}
	func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
		guard active else { return }
		switch peripheral.state {
		case .poweredOn: addServiceIfReady()
		case .unknown, .resetting: break
		default: fail()
		}
	}
	func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: (any Error)?) {
		guard active, service.uuid == serviceUUID else { return }
		guard error == nil, let serviceUUID else {
			fail()
			return
		}
		peripheral.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [serviceUUID]])
	}
	func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: (any Error)?) {
		if active, error != nil { fail() }
	}
	func peripheralManager(
		_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic
	) {
		guard active, peer == nil || peer?.identifier == central.identifier else { return }
		guard
			characteristic.uuid == CBUUID(string: BLEChannel.data.rawValue)
				|| characteristic.uuid == CBUUID(string: BLEChannel.status.rawValue)
		else { return }
		peer = central
		subscriptions.insert(characteristic.uuid.uuidString)
		if subscriptions.count == 2, !ready {
			ready = true
			continuation?.yield(.ready(capacity: central.maximumUpdateValueLength))
		}
	}
	func peripheralManager(
		_ peripheral: CBPeripheralManager, central: CBCentral,
		didUnsubscribeFrom characteristic: CBCharacteristic
	) {
		guard active, peer?.identifier == central.identifier else { return }
		continuation?.yield(.failed(BLETransferError.disconnected.localizedDescription))
	}
	func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
		// CoreBluetooth expects one response for the entire request batch.
		guard let first = requests.first else { return }
		guard active, ready,
			requests.allSatisfy({
				$0.central.identifier == peer?.identifier
					&& $0.characteristic.uuid == CBUUID(string: BLEChannel.control.rawValue)
					&& $0.offset == 0 && $0.value != nil
			})
		else {
			peripheral.respond(to: first, withResult: .writeNotPermitted)
			return
		}
		peripheral.respond(to: first, withResult: .success)
		for request in requests {
			if let value = request.value { continuation?.yield(.message(value, .control)) }
		}
	}
	func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) { drain() }
}
