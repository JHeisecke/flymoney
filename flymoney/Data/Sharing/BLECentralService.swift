//
//  BLECentralService.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-06-27.
//

import CoreBluetooth
import Foundation

@MainActor
final class BLECentralService: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
	private var manager: CBCentralManager!
	private var peripheral: CBPeripheral?
	private var controlChar: CBCharacteristic?
	private var dataChar: CBCharacteristic?
	private var statusChar: CBCharacteristic?

	private var continuation: AsyncStream<CentralEvent>.Continuation?

	func events() -> AsyncStream<CentralEvent> {
		AsyncStream { cont in
			self.continuation = cont
			self.manager = CBCentralManager(delegate: self, queue: .main)
		}
	}

	func start(serviceUUID: CBUUID) {
		manager.scanForPeripherals(withServices: [serviceUUID])
	}

	func writeControl(_ data: Data) {
		guard let peripheral, let controlChar else { return }
		peripheral.writeValue(data, for: controlChar, type: .withResponse)
	}

	func stop() {
		if let peripheral {
			manager.cancelPeripheralConnection(peripheral)
		}
		manager.stopScan()
		continuation?.finish()
	}

	func centralManagerDidUpdateState(_ central: CBCentralManager) {
		guard central.state == .poweredOn else {
			continuation?.yield(.error("Bluetooth unavailable"))
			return
		}
	}

	func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
		self.peripheral = peripheral
		peripheral.delegate = self
		manager.stopScan()
		manager.connect(peripheral)
	}

	func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
		continuation?.yield(.connected)
		peripheral.discoverServices(nil)
	}

	func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
		guard let services = peripheral.services else { return }
		for svc in services {
			peripheral.discoverCharacteristics(nil, for: svc)
		}
	}

	func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: (any Error)?) {
		for char in service.characteristics ?? [] {
			if char.properties.contains(.write) || char.properties.contains(.writeWithoutResponse) {
				controlChar = char
			} else if char.properties.contains(.notify) {
				if dataChar == nil {
					dataChar = char
					peripheral.setNotifyValue(true, for: char)
				} else {
					statusChar = char
					peripheral.setNotifyValue(true, for: char)
				}
			}
		}
		let mtu = peripheral.maximumWriteValueLength(for: .withResponse)
		continuation?.yield(.characteristicsReady(controlReady: controlChar != nil, dataReady: dataChar != nil, statusReady: statusChar != nil, mtu: mtu))
	}

	func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: (any Error)?) {
		guard let value = characteristic.value else { return }
		if characteristic == dataChar {
			continuation?.yield(.data(value))
		} else if characteristic == statusChar {
			continuation?.yield(.status(value))
		}
	}

	func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: (any Error)?) {
		continuation?.yield(.disconnected(reason: error?.localizedDescription))
	}

	enum CentralEvent {
		case connected
		case characteristicsReady(controlReady: Bool, dataReady: Bool, statusReady: Bool, mtu: Int)
		case data(Data)
		case status(Data)
		case disconnected(reason: String?)
		case error(String)
	}
}
