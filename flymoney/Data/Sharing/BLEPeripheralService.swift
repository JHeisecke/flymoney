//
//  BLEPeripheralService.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import CoreBluetooth
import Foundation

@MainActor
final class BLEPeripheralService: NSObject, CBPeripheralManagerDelegate {
	private var manager: CBPeripheralManager!
	private var service: CBMutableService!
	private var controlChar: CBMutableCharacteristic!
	private var dataChar: CBMutableCharacteristic!
	private var statusChar: CBMutableCharacteristic!

	private var continuation: AsyncStream<PeripheralEvent>.Continuation?
	private(set) var serviceUUID: CBUUID!

	func events() -> AsyncStream<PeripheralEvent> {
		AsyncStream { cont in
			self.continuation = cont
			self.manager = CBPeripheralManager(delegate: self, queue: .main)
		}
	}

	func start(serviceUUID uuidString: String) {
		let uuid = CBUUID(string: uuidString)
		self.serviceUUID = uuid
		service = CBMutableService(type: uuid, primary: true)

		let controlUUID = CBUUID(string: "E001")
		let dataUUID = CBUUID(string: "E002")
		let statusUUID = CBUUID(string: "E003")

		controlChar = CBMutableCharacteristic(
			type: controlUUID,
			properties: [.write],
			value: nil,
			permissions: [.writeable])

		dataChar = CBMutableCharacteristic(
			type: dataUUID,
			properties: [.notify],
			value: nil,
			permissions: [.readable])

		statusChar = CBMutableCharacteristic(
			type: statusUUID,
			properties: [.notify],
			value: nil,
			permissions: [.readable])

		service.characteristics = [controlChar, dataChar, statusChar]
		manager.add(service)
		manager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [uuid]])
	}

	func notifyData(_ frame: Data) {
		guard let char = dataChar else { return }
		manager.updateValue(frame, for: char, onSubscribedCentrals: nil)
	}

	func notifyStatus(_ frame: Data) {
		guard let char = statusChar else { return }
		manager.updateValue(frame, for: char, onSubscribedCentrals: nil)
	}

	func stop() {
		manager.stopAdvertising()
		manager.removeAllServices()
		continuation?.finish()
	}

	func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
		guard peripheral.state == .poweredOn else {
			continuation?.yield(.error("Bluetooth unavailable"))
			return
		}
		continuation?.yield(.ready)
	}

	func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
		continuation?.yield(.subscribed)
	}

	func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
		continuation?.yield(.unsubscribed)
	}

	func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
		for req in requests {
			guard let value = req.value else { continue }
			continuation?.yield(.controlWrite(value))
			peripheral.respond(to: req, withResult: .success)
		}
	}

	nonisolated func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {}

	enum PeripheralEvent {
		case ready
		case subscribed
		case unsubscribed
		case controlWrite(Data)
		case error(String)
	}
}
