//
//  SaveData.swift
//  RocketBuild
//
//  The locally-persisted profile: best height, coins, unlocked tiles, owned
//  tile instances, saved rocket configuration, settings and statistics. A plain
//  Codable value; the store handles I/O.
//

import Foundation

struct GameSettings: Codable {
    var soundEnabled: Bool = true
    var reducedEffects: Bool = false
}

struct Statistics: Codable {
    var totalRuns: Int = 0
    var totalCoinsEarned: Int = 0
    var totalDistance: Double = 0
    var hazardsDestroyed: Int = 0
}

struct SaveData: Codable {
    var bestHeight: Double = 0
    var coins: Int = 0
    /// Player level (1…15). Drives how many rocket slots are available.
    var level: Int = 1
    /// Accumulated experience toward the next level. Earned from flight distance.
    var xp: Int = 0
    /// Definition IDs the player has unlocked.
    var unlockedTileIDs: [String] = []
    /// Concrete owned tile instances (rolled quality etc.). This is the player's
    /// full deck — each assembly draws a random hand of 5 from it.
    var ownedTiles: [TileInstance] = []
    /// Persisted rocket loadout. Slot count is derived from `level` and kept in
    /// sync by Progression.
    var configuration: RocketConfiguration = RocketConfiguration(slotCount: 2)
    var settings = GameSettings()
    var statistics = Statistics()

    /// Persistent upgrade levels (Fuel Tank, Shield Strength, …).
    var upgradeLevels: [String: Int] = [:]

    /// The player's library (deck) begins as a *fixed* set of exactly 5 weak
    /// starter tiles — the lowest pip of each numbered suit — so every new game
    /// opens the same, deliberately underpowered. The deck grows only by
    /// acquiring new tiles from the shop's gacha; each assembly then draws a
    /// random hand of 5 from whatever the library currently holds.
    static let starterTileIDs = ["wan_1", "wan_2", "bamboo_1", "bamboo_2", "dot_1"]

    static func newProfile(catalog: TileCatalog) -> SaveData {
        var data = SaveData()

        // Fixed starter library: low-pip fuel/thrust/control tiles. Fall back to
        // whatever the catalog can offer if an ID is somehow missing so the deck
        // always reaches 5.
        var starters = starterTileIDs.filter { catalog.definition($0) != nil }
        if starters.count < 5 {
            let fill = catalog.allIDs.filter { !starters.contains($0) }
            starters += fill.prefix(5 - starters.count)
        }

        for id in starters.prefix(5) where catalog.definition(id) != nil {
            if !data.unlockedTileIDs.contains(id) { data.unlockedTileIDs.append(id) }
            data.ownedTiles.append(TileInstance(definitionID: id, quality: .common))
        }
        // A little seed coin so the shop is reachable on day one.
        data.coins = 120
        data.configuration.resize(to: Progression.slotCount(forLevel: data.level))
        return data
    }
}
