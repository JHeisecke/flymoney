import Foundation

protocol SharingTransport: Sendable {
	func send(_ payload: SharePayload) -> AsyncStream<TransferEvent>
	func receive() -> AsyncStream<TransferEvent>
}
