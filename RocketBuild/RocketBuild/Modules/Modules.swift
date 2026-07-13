//
//  Modules.swift
//  RocketBuild
//
//  Concrete RocketModule implementations. Each ability is a small class; they
//  are wired up by AbilityKind in the ModuleRegistry, never via a switch inside
//  gameplay logic.
//

import SceneKit

// MARK: Shield (White Dragon)

final class ShieldModule: BaseModule {
    private var cooldown: Double = 0

    override func update(deltaTime: TimeInterval, context: FlightContext) {
        guard isFunctional else { return }
        cooldown = max(0, cooldown - deltaTime)
        // Regenerate a depleted shield slowly over time.
        if context.shieldCharge < power && cooldown == 0 {
            context.shieldCharge = min(power, context.shieldCharge + deltaTime * 4)
        }
    }

    override func activate(context: FlightContext) {
        guard isFunctional, cooldown == 0 else { return }
        context.shieldCharge = power
        cooldown = descriptor.secondary
        context.requestEffect(.shieldRipple)
    }
}

// MARK: Magnet (Green Dragon)

final class MagnetModule: BaseModule {
    override var power: Double {
        let base = super.power
        return passive == .doubleMagnet ? base * 2 : base
    }

    override func update(deltaTime: TimeInterval, context: FlightContext) {
        guard isFunctional else { return }
        context.magnetRadius = max(context.magnetRadius, power)
    }
}

// MARK: Explosion (Red Dragon)

final class ExplosionModule: BaseModule {
    private var cooldown: Double = 0

    override func update(deltaTime: TimeInterval, context: FlightContext) {
        cooldown = max(0, cooldown - deltaTime)
    }

    override func activate(context: FlightContext) {
        guard isFunctional, cooldown == 0 else { return }
        context.detonate(radius: Float(power))
        cooldown = descriptor.secondary
    }
}

// MARK: Radar (East)

final class RadarModule: BaseModule {
    override func update(deltaTime: TimeInterval, context: FlightContext) {
        guard isFunctional else { return }
        context.radarRange = max(context.radarRange, Float(power))
        if passive == .meteorDetection { context.meteorDetection = true }
    }
}

// MARK: Speed Boost (South)

final class SpeedBoostModule: BaseModule {
    private var cooldown: Double = 0
    private var remaining: Double = 0

    override func update(deltaTime: TimeInterval, context: FlightContext) {
        cooldown = max(0, cooldown - deltaTime)
        if remaining > 0 {
            remaining -= deltaTime
            context.speedMultiplier = max(context.speedMultiplier, 1.8)
        }
    }

    override func activate(context: FlightContext) {
        guard isFunctional, cooldown == 0 else { return }
        remaining = descriptor.secondary
        cooldown = descriptor.secondary * 3
        context.requestEffect(.boostFlash)
    }
}

// MARK: Repair (West)

final class RepairModule: BaseModule {
    private var timer: Double = 0

    override func update(deltaTime: TimeInterval, context: FlightContext) {
        guard isFunctional else { return }
        timer += deltaTime
        let interval = max(2, descriptor.secondary)
        if timer >= interval {
            timer = 0
            context.repairHull(by: power)
        }
        // Gold auto-repair also mends other damaged modules occasionally.
        if passive == .autoRepair && timer == 0 {
            context.repairModules(by: power * 0.5)
        }
    }
}

// MARK: Stability (North)

final class StabilityModule: BaseModule {
    override func update(deltaTime: TimeInterval, context: FlightContext) {
        guard isFunctional else { return }
        context.stability += Float(power)
    }
}

// MARK: Fuel Capacity (Characters 萬)

final class FuelModule: BaseModule {
    override func install(on rocket: RocketBody) {
        super.install(on: rocket)
        var bonus = power
        if passive == .fuelEfficiency { bonus *= 1.25 }
        rocket.registerFuelBonus(bonus)
    }
}

// MARK: Thruster (Bamboo 條)

final class ThrusterModule: BaseModule {
    override func update(deltaTime: TimeInterval, context: FlightContext) {
        guard isFunctional else { return }
        context.thrust += Float(power)
    }
}

// MARK: Control (Dots 筒)

final class ControlModule: BaseModule {
    override func update(deltaTime: TimeInterval, context: FlightContext) {
        guard isFunctional else { return }
        context.controlBonus += Float(power)
    }
}
