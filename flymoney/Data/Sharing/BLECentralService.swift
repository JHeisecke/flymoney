//
//  BLECentralService.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-10-30.
//

import CoreBluetooth
import Foundation

@MainActor
final class BLECentralService: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate, BLERadio {
	private var manager: CBCentralManager?
	private var peripheral: CBPeripheral?
	private var serviceUUID: CBUUID?
	private var characteristics: [BLEChannel: CBCharacteristic] = [:]
	private var continuation: AsyncStream<BLERadioEvent>.Continuation?
	private var active = false
	private var scanning = false
	private var ready = false
	private var discovery = BLEDiscoveryState()
	private var writes: [Data] = []
	private var writing = false

	func events() -> AsyncStream<BLERadioEvent> {
		let pair = AsyncStream<BLERadioEvent>.makeStream()
		continuation = pair.continuation
		active = true
		manager = CBCentralManager(delegate: self, queue: .main)
		return pair.stream
	}
	func start(serviceUUID: String) {
		self.serviceUUID = CBUUID(string: serviceUUID)
		scanIfReady()
	}
	private func scanIfReady() {
		guard active, let manager, manager.state == .poweredOn, let serviceUUID, !scanning, peripheral == nil
		else { return }
		scanning = true
		manager.scanForPeripherals(withServices: [serviceUUID])
	}
	func send(_ data: Data, on channel: BLEChannel) throws {
		guard active, ready, let peripheral, channel == .control else { throw BLETransferError.disconnected }
		guard data.count <= peripheral.maximumWriteValueLength(for: .withResponse) else {
			throw BLETransferError.capacity
		}
		writes.append(data)
		drain()
	}
	private func drain() {
		guard active, !writing, let peripheral, let char = characteristics[.control], let data = writes.first
		else { return }
		writing = true
		peripheral.writeValue(data, for: char, type: .withResponse)
	}
	func stop() {
		active = false
		peripheral?.delegate = nil
		if let peripheral { manager?.cancelPeripheralConnection(peripheral) }
		manager?.stopScan()
		manager?.delegate = nil
		manager = nil
		peripheral = nil
		serviceUUID = nil
		characteristics.removeAll()
		writes.removeAll()
		scanning = false
		writing = false
		ready = false
		discovery = BLEDiscoveryState()
		continuation?.finish()
		continuation = nil
	}
	private func fail(_ error: BLETransferError = .disconnected) {
		continuation?.yield(.failed(error.localizedDescription))
	}
	func centralManagerDidUpdateState(_ central: CBCentralManager) {
		guard active else { return }
		switch central.state {
		case .poweredOn: scanIfReady()
		case .unknown, .resetting: break
		default:
			continuation?.yield(
				.failed(String(localized: "Bluetooth is unavailable. Check Settings and try again.")))
		}
	}
	func centralManager(
		_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any],
		rssi RSSI: NSNumber
	) {
		guard active, self.peripheral == nil else { return }
		self.peripheral = peripheral
		peripheral.delegate = self
		central.stopScan()
		central.connect(peripheral)
	}
	func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
		guard active, peripheral == self.peripheral, let serviceUUID else { return }
		peripheral.discoverServices([serviceUUID])
	}
	func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: (any Error)?)
	{ if active { fail() } }
	func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
		guard active else { return }
		guard error == nil, let service = peripheral.services?.first(where: { $0.uuid == serviceUUID }) else {
			fail()
			return
		}
		peripheral.discoverCharacteristics(
			[BLEChannel.control, .data, .status].map { CBUUID(string: $0.rawValue) }, for: service)
	}
	func peripheral(
		_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: (any Error)?
	) {
		guard active, service.uuid == serviceUUID else { return }
		guard error == nil else {
			fail()
			return
		}
		do {
			try discovery.discover(
				(service.characteristics ?? []).map {
					BLEDiscoveryState.Characteristic(
						uuid: $0.uuid.uuidString, writable: $0.properties.contains(.write),
						notifiable: $0.properties.contains(.notify))
				})
		} catch {
			fail(.invalidMessage)
			return
		}
		for channel in [BLEChannel.control, .data, .status] {
			characteristics[channel] = service.characteristics?.first {
				$0.uuid == CBUUID(string: channel.rawValue)
			}
		}
		for channel in [BLEChannel.data, .status] {
			if let char = characteristics[channel] { peripheral.setNotifyValue(true, for: char) }
		}
	}
	func peripheral(
		_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic,
		error: (any Error)?
	) {
		guard active else { return }
		guard error == nil, characteristic.isNotifying else {
			fail()
			return
		}
		do {
			try discovery.subscribed(
				uuid: characteristic.uuid.uuidString, notifying: characteristic.isNotifying)
		} catch {
			fail(.invalidMessage)
			return
		}
		if !ready, discovery.ready {
			ready = true
			continuation?.yield(.ready(capacity: peripheral.maximumWriteValueLength(for: .withResponse)))
		}
	}
	func peripheral(
		_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: (any Error)?
	) {
		guard active else { return }
		guard error == nil, let value = characteristic.value else {
			fail()
			return
		}
		for channel in [BLEChannel.data, .status] where characteristics[channel] == characteristic {
			continuation?.yield(.message(value, channel))
		}
	}
	func peripheral(
		_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: (any Error)?
	) {
		guard active, characteristic == characteristics[.control], writing, !writes.isEmpty else { return }
		guard error == nil else {
			fail()
			return
		}
		let data = writes.removeFirst()
		writing = false
		continuation?.yield(.sent(data, .control))
		drain()
	}
	func centralManager(
		_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: (any Error)?
	) {
		if active { fail() }
	}
}
