//
//  MinesweeperPalette.swift
//  flymoney
//
//  Created by Javier Heisecke on 2026-11-14.
//

import SwiftUI

// The board has its own retro palette; the surrounding screen uses Theme.
enum MinesweeperPalette {
    static let panel = Color(white: 0.78)
    static let shadow = Color(white: 0.45)
    static let highlight = Color.white
    static let ink = Color.black

    static func number(_ value: Int) -> Color {
        switch value {
        case 1: .blue
        case 2: Color(red: 0, green: 0.4, blue: 0)
        case 3: .red
        case 4: Color(red: 0, green: 0, blue: 0.45)
        case 5: Color(red: 0.5, green: 0, blue: 0)
        case 6: Color(red: 0, green: 0.4, blue: 0.4)
        default: .black
        }
    }
}
