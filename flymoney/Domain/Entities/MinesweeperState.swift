//
//  MinesweeperState.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-14.
//

enum MinesweeperState: Equatable {
    case ready
    case playing
    case won
    case lost

    var isFinished: Bool { self == .won || self == .lost }
}
