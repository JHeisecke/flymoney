import Foundation

enum TransferEvent: Equatable, Sendable {
	case handshaking
	case transferring(progress: Double)
	case completed
	case failed(reason: String)
}
