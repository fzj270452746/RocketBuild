//
//  TileModel.swift
//  RocketBuild
//
//  Data-driven description of every mahjong tile. There is deliberately no
//  giant `switch tile { case .fiveWan: ... }` anywhere in the game — a tile is
//  just data (a definition) plus an ability descriptor, and modules are built
//  from that data by the module registry.
//

import Foundation

enum TileSuit: String, Codable {
    case character  // 萬
    case bamboo     // 條
    case dot        // 筒
    case honor      // winds & dragons
}

enum TileQuality: String, Codable, CaseIterable {
    case common, blue, purple, gold

    /// Multiplier applied to an ability's magnitude.
    var powerScale: Double {
        switch self {
        case .common: return 1.0
        case .blue:   return 1.15
        case .purple: return 1.35
        case .gold:   return 1.6
        }
    }
}

/// The kind of effect a tile provides. Adding a case here + registering a
/// builder is the only work needed to add a new ability, keeping switch
/// statements out of gameplay code.
enum AbilityKind: String, Codable {
    case shield          // White dragon
    case magnet          // Green dragon
    case explosion       // Red dragon
    case radar           // East
    case speedBoost      // South
    case repairKit       // West
    case stability       // North
    case fuelCapacity    // Characters (萬)
    case thruster        // Bamboo (條) — acceleration / turbo
    case control         // Dots (筒) — rotation / turning
}

/// A passive bonus carried only by gold tiles.
enum PassiveBonus: String, Codable {
    case fuelEfficiency
    case criticalShield
    case doubleMagnet
    case autoRepair
    case meteorDetection
}

/// Numeric parameters for an ability. Interpretation depends on `kind`, but
/// keeping them as named scalars avoids per-tile hardcoding.
struct AbilityDescriptor: Codable {
    var kind: AbilityKind
    /// Primary magnitude (fuel amount, shield HP, magnet radius, etc.).
    var magnitude: Double
    /// Secondary tuning value (cooldown, duration, rate…). Optional.
    var secondary: Double

    init(kind: AbilityKind, magnitude: Double, secondary: Double = 0) {
        self.kind = kind
        self.magnitude = magnitude
        self.secondary = secondary
    }
}

/// Immutable definition of a tile as authored in data.
struct TileDefinition: Codable, Identifiable {
    var id: String            // e.g. "wan_5", "dragon_white"
    var displayName: String   // English label for menus
    var glyph: String         // character drawn on the tile face
    var suit: TileSuit
    var ability: AbilityDescriptor
    /// Contribution to hidden rocket stats when installed (added to totals).
    var statContribution: RocketStats
    /// Base mass added to the rocket.
    var weight: Double

    /// Face texture cache key — shared across qualities of the same glyph.
    var faceCacheKey: String { "\(suit.rawValue)_\(glyph)" }
}

/// A concrete, owned instance of a tile: a definition at a rolled quality with
/// an optional gold passive.
struct TileInstance: Codable, Identifiable, Equatable {
    var instanceID: UUID
    var definitionID: String
    var quality: TileQuality
    var passive: PassiveBonus?

    var id: UUID { instanceID }

    init(definitionID: String, quality: TileQuality, passive: PassiveBonus? = nil) {
        self.instanceID = UUID()
        self.definitionID = definitionID
        self.quality = quality
        self.passive = passive
    }

    static func == (l: TileInstance, r: TileInstance) -> Bool {
        l.instanceID == r.instanceID
    }
}
