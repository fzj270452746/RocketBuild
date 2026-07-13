//
//  TileCatalog.swift
//  RocketBuild
//
//  Loads all tile definitions from a bundled JSON resource. If the resource is
//  missing (or malformed) it falls back to a code-authored default set so the
//  game is always playable. Owned by the composition root and injected.
//

import Foundation

final class TileCatalog {

    private(set) var definitions: [String: TileDefinition] = [:]
    private(set) var ordered: [TileDefinition] = []

    init(bundle: Bundle = .main) {
        let defs = Self.loadFromBundle(bundle) ?? Self.defaultDefinitions()
        ordered = defs
        for d in defs { definitions[d.id] = d }
    }

    func definition(_ id: String) -> TileDefinition? { definitions[id] }

    var allIDs: [String] { ordered.map(\.id) }

    // MARK: JSON loading

    private static func loadFromBundle(_ bundle: Bundle) -> [TileDefinition]? {
        guard let url = bundle.url(forResource: "Tiles", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try JSONDecoder().decode([TileDefinition].self, from: data)
        } catch {
            #if DEBUG
            print("TileCatalog: failed to decode Tiles.json — \(error). Using defaults.")
            #endif
            return nil
        }
    }

    // MARK: Fallback data

    /// Chinese numeral prefixes for the numbered suits (index 0 == "一"/1).
    private static let numerals = ["一", "二", "三", "四", "五", "六", "七", "八", "九"]

    /// Mirrors the ability table from the design document. This doubles as the
    /// canonical source used to regenerate Tiles.json. It contains the full set
    /// of 34 standard mahjong tile *types*: the three numbered suits 1–9
    /// (萬/條/筒) plus the seven honor tiles (four winds + three dragons).
    ///
    /// The numbered suits share one ability each but scale their magnitude with
    /// the pip number, so "1 vs 9" is a real power/weight trade-off. The honor
    /// tiles keep the marquee active abilities.
    static func defaultDefinitions() -> [TileDefinition] {
        func stats(_ kv: (WritableKeyPath<RocketStats, Double>, Double)...) -> RocketStats {
            var s = RocketStats()
            for (kp, v) in kv { s[keyPath: kp] = v }
            return s
        }

        var defs: [TileDefinition] = []

        // MARK: Honor tiles — dragons & winds carry the marquee active abilities.
        defs += [
            TileDefinition(id: "dragon_white", displayName: "White Dragon", glyph: "白",
                           suit: .honor, ability: .init(kind: .shield, magnitude: 40, secondary: 6),
                           statContribution: stats((\.shield, 40), (\.weight, 3)), weight: 3),
            TileDefinition(id: "dragon_green", displayName: "Green Dragon", glyph: "發",
                           suit: .honor, ability: .init(kind: .magnet, magnitude: 6, secondary: 0),
                           statContribution: stats((\.magnetRange, 6), (\.weight, 2)), weight: 2),
            TileDefinition(id: "dragon_red", displayName: "Red Dragon", glyph: "中",
                           suit: .honor, ability: .init(kind: .explosion, magnitude: 5, secondary: 8),
                           statContribution: stats((\.weight, 2)), weight: 2),
            TileDefinition(id: "wind_east", displayName: "East Wind", glyph: "東",
                           suit: .honor, ability: .init(kind: .radar, magnitude: 12, secondary: 0),
                           statContribution: stats((\.control, 1)), weight: 2),
            TileDefinition(id: "wind_south", displayName: "South Wind", glyph: "南",
                           suit: .honor, ability: .init(kind: .speedBoost, magnitude: 3, secondary: 4),
                           statContribution: stats((\.speed, 3)), weight: 2),
            TileDefinition(id: "wind_west", displayName: "West Wind", glyph: "西",
                           suit: .honor, ability: .init(kind: .repairKit, magnitude: 20, secondary: 10),
                           statContribution: stats((\.weight, 2)), weight: 2),
            TileDefinition(id: "wind_north", displayName: "North Wind", glyph: "北",
                           suit: .honor, ability: .init(kind: .stability, magnitude: 2, secondary: 0),
                           statContribution: stats((\.control, 2), (\.weight, 1)), weight: 2),
        ]

        // MARK: Numbered suits 1–9, generated so the pip number scales power.
        for pip in 1...9 {
            let n = Double(pip)
            let numeral = numerals[pip - 1]

            // Characters (萬) — fuel capacity 15 → 55, heavier as it grows.
            let fuel = 12 + n * 5                    // 17 … 57
            let wanWeight = (1 + n * 0.28).rounded() // 1 … 4
            defs.append(TileDefinition(
                id: "wan_\(pip)", displayName: "\(pip) Characters", glyph: "\(numeral)萬",
                suit: .character, ability: .init(kind: .fuelCapacity, magnitude: fuel),
                statContribution: stats((\.fuel, fuel), (\.weight, wanWeight)), weight: wanWeight))

            // Bamboo (條) — thrusters 1.2 → 5.2 speed, heavier as it grows.
            let thrust = 0.8 + n * 0.5               // 1.3 … 5.3
            let bambooWeight = (1 + n * 0.25).rounded()
            defs.append(TileDefinition(
                id: "bamboo_\(pip)", displayName: "\(pip) Bamboo", glyph: "\(numeral)條",
                suit: .bamboo, ability: .init(kind: .thruster, magnitude: thrust,
                                              secondary: n >= 6 ? 1 : 0),
                statContribution: stats((\.speed, thrust), (\.weight, bambooWeight)), weight: bambooWeight))

            // Dots (筒) — control 1.0 → 4.0, lightest suit.
            let control = 0.7 + n * 0.37             // 1.07 … 4.0
            let dotWeight = (0.5 + n * 0.2).rounded()
            defs.append(TileDefinition(
                id: "dot_\(pip)", displayName: "\(pip) Dots", glyph: "\(numeral)筒",
                suit: .dot, ability: .init(kind: .control, magnitude: control,
                                           secondary: n >= 7 ? 1 : 0),
                statContribution: stats((\.control, control), (\.weight, dotWeight)), weight: dotWeight))
        }

        return defs
    }
}
