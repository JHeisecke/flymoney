//
//  MinesweeperTestGenerator.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-14.
//

struct MinesweeperTestGenerator: RandomNumberGenerator {
    var seed: UInt64 = 7

    mutating func next() -> UInt64 {
        seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return seed
    }
}
