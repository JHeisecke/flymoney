//
//  BLESessionKeys.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-10-30.
//

import CryptoKit
import Foundation

struct BLESessionKeys {
	let data: SharedSecret
	let control: SharedSecret
	let status: SharedSecret
	init(privateKey: Curve25519.KeyAgreement.PrivateKey, peer: Curve25519.KeyAgreement.PublicKey, sid: Data) throws
	{
		data = try SharedSecret.sender(
			privateKey: privateKey, receiverPublicKey: peer, sessionID: sid, purpose: "data")
		control = try SharedSecret.sender(
			privateKey: privateKey, receiverPublicKey: peer, sessionID: sid, purpose: "control")
		status = try SharedSecret.sender(
			privateKey: privateKey, receiverPublicKey: peer, sessionID: sid, purpose: "status")
	}
}
