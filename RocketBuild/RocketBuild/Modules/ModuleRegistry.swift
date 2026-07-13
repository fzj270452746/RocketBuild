//
//  ModuleRegistry.swift
//  RocketBuild
//
//  Runtime factory that turns a TileInstance into a live RocketModule. Builders
//  are stored in a dictionary keyed by AbilityKind and registered at init time,
//  so new abilities are added by registering a closure rather than extending a
//  switch statement. This is the "Runtime Module Factory" from the design doc.
//

import Foundation

final class ModuleRegistry {

    typealias Builder = (AbilityDescriptor, TileQuality, PassiveBonus?) -> RocketModule

    private var builders: [AbilityKind: Builder] = [:]
    private let catalog: TileCatalog

    init(catalog: TileCatalog) {
        self.catalog = catalog
        registerDefaults()
    }

    func register(_ kind: AbilityKind, builder: @escaping Builder) {
        builders[kind] = builder
    }

    /// Builds a module for an owned tile instance, or nil if its definition or
    /// ability builder is unknown.
    func makeModule(for instance: TileInstance) -> RocketModule? {
        guard let def = catalog.definition(instance.definitionID),
              let builder = builders[def.ability.kind] else { return nil }
        return builder(def.ability, instance.quality, instance.passive)
    }

    private func registerDefaults() {
        register(.shield)      { ShieldModule(descriptor: $0, quality: $1, passive: $2) }
        register(.magnet)      { MagnetModule(descriptor: $0, quality: $1, passive: $2) }
        register(.explosion)   { ExplosionModule(descriptor: $0, quality: $1, passive: $2) }
        register(.radar)       { RadarModule(descriptor: $0, quality: $1, passive: $2) }
        register(.speedBoost)  { SpeedBoostModule(descriptor: $0, quality: $1, passive: $2) }
        register(.repairKit)   { RepairModule(descriptor: $0, quality: $1, passive: $2) }
        register(.stability)   { StabilityModule(descriptor: $0, quality: $1, passive: $2) }
        register(.fuelCapacity){ FuelModule(descriptor: $0, quality: $1, passive: $2) }
        register(.thruster)    { ThrusterModule(descriptor: $0, quality: $1, passive: $2) }
        register(.control)     { ControlModule(descriptor: $0, quality: $1, passive: $2) }
    }
}
