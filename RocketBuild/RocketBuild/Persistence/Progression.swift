//
//  Progression.swift
//  RocketBuild
//
//  Handles unlocks and persistent upgrades on top of the SaveStore. Kept as a
//  thin service so the flight scene can grant rewards (e.g. golden mahjong) via
//  dependency injection rather than reaching into a global.
//

import Foundation

final class Progression {

    private let store: SaveStore

    init(store: SaveStore) {
        self.store = store
    }

    /// Unlocks a random tile the player does not yet own, if any remain, and
    /// grants an owned instance with a randomly-rolled quality.
    @discardableResult
    func unlockRandomTile(from catalog: TileCatalog) -> TileInstance? {
        let locked = catalog.allIDs.filter { !store.data.unlockedTileIDs.contains($0) }
        let targetID = locked.randomElement() ?? catalog.allIDs.randomElement()
        guard let id = targetID else { return nil }

        let quality = rollQuality()
        let passive: PassiveBonus? = quality == .gold ? PassiveBonus.allCases.randomElement() : nil
        let instance = TileInstance(definitionID: id, quality: quality, passive: passive)

        store.update { d in
            if !d.unlockedTileIDs.contains(id) { d.unlockedTileIDs.append(id) }
            d.ownedTiles.append(instance)
        }
        return instance
    }

    /// Weighted rarity roll: gold is rare, common is frequent.
    private func rollQuality() -> TileQuality {
        let roll = Double.random(in: 0...1)
        switch roll {
        case ..<0.60: return .common
        case ..<0.85: return .blue
        case ..<0.96: return .purple
        default:      return .gold
        }
    }

    // MARK: Gacha (coin sink)

    /// Standard single / ten-pull costs. Ten-pull gives a small discount.
    static let singlePullCost = 50
    static let tenPullCost = 450

    var coins: Int { store.data.coins }

    /// Draws one random tile from the whole catalog (duplicates allowed — they
    /// stack as extra owned instances), rolling a fresh quality. Deducts coins;
    /// returns nil if the player cannot afford it.
    @discardableResult
    func pullOne(from catalog: TileCatalog, cost: Int = Progression.singlePullCost) -> TileInstance? {
        guard store.data.coins >= cost else { return nil }
        store.update { $0.coins -= cost }
        return grantRandomTile(from: catalog)
    }

    /// A ten-pull: ten draws for a discounted lump sum. Returns the tiles drawn,
    /// or an empty array if unaffordable.
    @discardableResult
    func pullTen(from catalog: TileCatalog, cost: Int = Progression.tenPullCost) -> [TileInstance] {
        guard store.data.coins >= cost else { return [] }
        store.update { $0.coins -= cost }
        return (0..<10).compactMap { _ in grantRandomTile(from: catalog) }
    }

    /// Grants a random owned tile (any catalog entry) at a rolled quality,
    /// also flagging its definition as unlocked. Does not touch coins.
    @discardableResult
    private func grantRandomTile(from catalog: TileCatalog) -> TileInstance? {
        guard let id = catalog.allIDs.randomElement() else { return nil }
        let quality = rollQuality()
        let passive: PassiveBonus? = quality == .gold ? PassiveBonus.allCases.randomElement() : nil
        let instance = TileInstance(definitionID: id, quality: quality, passive: passive)
        store.update { d in
            if !d.unlockedTileIDs.contains(id) { d.unlockedTileIDs.append(id) }
            d.ownedTiles.append(instance)
        }
        return instance
    }

    // MARK: Levelling & slots

    /// Max player level. Slots stop growing here.
    static let maxLevel = 15

    /// The player starts with 2 slots and earns one more on reaching levels 3, 8
    /// and 15 — capping at 5. `slotUnlockLevels[i]` is the level at which slot
    /// count becomes `i + 3` (i.e. level 3 → 3 slots, 8 → 4, 15 → 5).
    static let slotUnlockLevels = [3, 8, 15]

    /// Rocket slots available at a given player level.
    static func slotCount(forLevel level: Int) -> Int {
        var slots = 2
        for unlock in slotUnlockLevels where level >= unlock { slots += 1 }
        return slots
    }

    /// XP required to advance *from* the given level to the next one. Grows so
    /// later levels take longer. Level is capped at `maxLevel`.
    static func xpToNext(fromLevel level: Int) -> Int {
        guard level < maxLevel else { return .max }
        return 100 + (level - 1) * 80   // L1→2 needs 100, L2→3 needs 180, …
    }

    var level: Int { store.data.level }
    var xp: Int { store.data.xp }
    var xpToNext: Int { Self.xpToNext(fromLevel: store.data.level) }
    var slotCount: Int { Self.slotCount(forLevel: store.data.level) }
    var isMaxLevel: Bool { store.data.level >= Self.maxLevel }

    /// The result of granting experience: how many levels were gained and which
    /// slot unlocks (new slot counts) were crossed, so the UI can celebrate.
    struct LevelUpResult {
        var leveledUp: Bool
        var newLevel: Int
        var slotsUnlocked: [Int]   // new slot counts reached this grant
    }

    /// Awards XP (typically derived from a run's altitude), applying as many
    /// level-ups as the XP covers, and resizing the rocket config when a slot
    /// unlock level is crossed. Returns what changed for UI feedback.
    @discardableResult
    func awardExperience(_ amount: Int) -> LevelUpResult {
        guard amount > 0 else {
            return LevelUpResult(leveledUp: false, newLevel: store.data.level, slotsUnlocked: [])
        }
        var slotsUnlocked: [Int] = []
        let startLevel = store.data.level
        store.update { d in
            d.xp += amount
            while d.level < Self.maxLevel {
                let need = Self.xpToNext(fromLevel: d.level)
                guard d.xp >= need else { break }
                d.xp -= need
                let before = Self.slotCount(forLevel: d.level)
                d.level += 1
                let after = Self.slotCount(forLevel: d.level)
                if after > before { slotsUnlocked.append(after) }
            }
            if d.level >= Self.maxLevel { d.xp = 0 }
            d.configuration.resize(to: Self.slotCount(forLevel: d.level))
        }
        return LevelUpResult(leveledUp: store.data.level > startLevel,
                             newLevel: store.data.level,
                             slotsUnlocked: slotsUnlocked)
    }

    // MARK: Upgrades

    func upgradeLevel(_ key: String) -> Int { store.data.upgradeLevels[key] ?? 0 }

    /// Cost scales with current level.
    func upgradeCost(_ key: String) -> Int { (upgradeLevel(key) + 1) * 50 }

    @discardableResult
    func purchaseUpgrade(_ key: String) -> Bool {
        let cost = upgradeCost(key)
        guard store.data.coins >= cost else { return false }
        store.update { d in
            d.coins -= cost
            d.upgradeLevels[key, default: 0] += 1
        }
        return true
    }
}

extension PassiveBonus: CaseIterable {
    static var allCases: [PassiveBonus] {
        [.fuelEfficiency, .criticalShield, .doubleMagnet, .autoRepair, .meteorDetection]
    }
}
