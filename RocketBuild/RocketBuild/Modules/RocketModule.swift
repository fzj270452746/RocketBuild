//
//  RocketModule.swift
//  RocketBuild
//
//  Protocol-driven ability system. Every installed mahjong tile becomes a
//  RocketModule. Modules are produced by a registry keyed on AbilityKind, so
//  there is no `switch tile` scattered through the code — registering a builder
//  closure is all it takes to add behaviour.
//

import SceneKit

/// A live ability attached to the rocket. Implementations hold their own state
/// (cooldowns, remaining charges) and mutate the flight context.
protocol RocketModule: AnyObject {
    var descriptor: AbilityDescriptor { get }
    /// Effective power after quality scaling has been applied.
    var power: Double { get }
    /// True while the module is functional (collisions can disable it).
    var isFunctional: Bool { get }

    /// Called once when installed onto the assembled rocket.
    func install(on rocket: RocketBody)
    /// Called each flight frame.
    func update(deltaTime: TimeInterval, context: FlightContext)
    /// Player tapped the ability button (only meaningful for activatable ones).
    func activate(context: FlightContext)
    /// Collision damage — may disable the module.
    func takeDamage(_ amount: Double)
    /// Restore module health (used by auto-repair passives).
    func heal(_ amount: Double)
    /// Detach and clean up visuals.
    func remove()
}

extension RocketModule {
    func activate(context: FlightContext) {}
    func update(deltaTime: TimeInterval, context: FlightContext) {}
}

/// Shared base that stores common state so concrete modules stay small.
class BaseModule: RocketModule {
    let descriptor: AbilityDescriptor
    let quality: TileQuality
    let passive: PassiveBonus?
    private(set) var health: Double = 100
    weak var rocket: RocketBody?

    init(descriptor: AbilityDescriptor, quality: TileQuality, passive: PassiveBonus?) {
        self.descriptor = descriptor
        self.quality = quality
        self.passive = passive
    }

    var power: Double { descriptor.magnitude * quality.powerScale }
    var isFunctional: Bool { health > 0 }

    func install(on rocket: RocketBody) { self.rocket = rocket }

    // Declared here (not just in the protocol extension) so concrete modules
    // can `override` them. Base behaviour is intentionally empty.
    func update(deltaTime: TimeInterval, context: FlightContext) {}
    func activate(context: FlightContext) {}

    func takeDamage(_ amount: Double) {
        health = max(0, health - amount)
    }

    func heal(_ amount: Double) {
        health = min(100, health + amount)
    }

    func remove() { rocket = nil }
}
