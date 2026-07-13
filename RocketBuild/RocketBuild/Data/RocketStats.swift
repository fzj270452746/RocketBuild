//
//  RocketStats.swift
//  RocketBuild
//
//  The hidden attribute vector for a rocket. Modelled as an additive value type
//  so a rocket's totals are simply the sum of its base stats and every
//  installed module's contribution — no bespoke aggregation logic per stat.
//

import Foundation

struct RocketStats: Codable, Equatable {
    var fuel: Double = 0            // max fuel capacity
    var speed: Double = 0           // ascent speed bonus
    var weight: Double = 0          // heavier = slower / more inertia
    var shield: Double = 0          // shield hit points
    var heatResist: Double = 0      // resistance to lightning / lasers
    var magnetRange: Double = 0     // pickup attraction radius
    var energyCapacity: Double = 0  // crystal energy buffer
    var control: Double = 0         // lateral responsiveness

    static func + (l: RocketStats, r: RocketStats) -> RocketStats {
        RocketStats(
            fuel: l.fuel + r.fuel,
            speed: l.speed + r.speed,
            weight: l.weight + r.weight,
            shield: l.shield + r.shield,
            heatResist: l.heatResist + r.heatResist,
            magnetRange: l.magnetRange + r.magnetRange,
            energyCapacity: l.energyCapacity + r.energyCapacity,
            control: l.control + r.control
        )
    }

    static func += (l: inout RocketStats, r: RocketStats) { l = l + r }

    /// Scales every beneficial stat by `factor`, leaving `weight` untouched so a
    /// higher-quality tile is strictly better (more benefit, same mass).
    func scaledBenefits(by factor: Double) -> RocketStats {
        RocketStats(
            fuel: fuel * factor,
            speed: speed * factor,
            weight: weight,
            shield: shield * factor,
            heatResist: heatResist * factor,
            magnetRange: magnetRange * factor,
            energyCapacity: energyCapacity * factor,
            control: control * factor
        )
    }

    /// Base chassis stats every rocket starts with before modules.
    static var baseChassis: RocketStats {
        RocketStats(fuel: 60, speed: 6, weight: 8, shield: 0,
                    heatResist: 1, magnetRange: 2, energyCapacity: 40, control: 4)
    }
}
