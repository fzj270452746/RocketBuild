//
//  Palette.swift
//  RocketBuild
//
//  Central place for the bright, slightly-cartoon colour language described
//  in the design doc. Kept as plain data so factories and UI can share it.
//

import UIKit

enum Palette {

    // Space gradient backdrop.
    static let spaceTop = UIColor(red: 0.05, green: 0.03, blue: 0.16, alpha: 1)
    static let spaceBottom = UIColor(red: 0.18, green: 0.10, blue: 0.38, alpha: 1)

    // Rocket body metals.
    static let hull = UIColor(red: 0.86, green: 0.89, blue: 0.95, alpha: 1)
    static let hullAccent = UIColor(red: 0.98, green: 0.42, blue: 0.36, alpha: 1)
    static let engineMetal = UIColor(red: 0.55, green: 0.58, blue: 0.66, alpha: 1)

    // Interface accents.
    static let hud = UIColor(red: 0.60, green: 0.92, blue: 1.0, alpha: 1)
    static let warning = UIColor(red: 1.0, green: 0.72, blue: 0.22, alpha: 1)
    static let good = UIColor(red: 0.44, green: 0.95, blue: 0.66, alpha: 1)
    static let coin = UIColor(red: 1.0, green: 0.84, blue: 0.30, alpha: 1)

    /// Quality colours reused across catalog, assembly UI and tile glow.
    static func quality(_ q: TileQuality) -> UIColor {
        switch q {
        case .common: return UIColor(white: 0.82, alpha: 1)
        case .blue:   return UIColor(red: 0.35, green: 0.62, blue: 1.0, alpha: 1)
        case .purple: return UIColor(red: 0.72, green: 0.42, blue: 1.0, alpha: 1)
        case .gold:   return UIColor(red: 1.0, green: 0.80, blue: 0.28, alpha: 1)
        }
    }

    /// Suit colours for the mahjong faces.
    static func suit(_ suit: TileSuit) -> UIColor {
        switch suit {
        case .character: return UIColor(red: 0.90, green: 0.26, blue: 0.30, alpha: 1)   // 萬 red
        case .bamboo:    return UIColor(red: 0.20, green: 0.68, blue: 0.36, alpha: 1)    // 條 green
        case .dot:       return UIColor(red: 0.25, green: 0.52, blue: 0.90, alpha: 1)    // 筒 blue
        case .honor:     return UIColor(red: 0.30, green: 0.30, blue: 0.34, alpha: 1)    // honors
        }
    }
}
