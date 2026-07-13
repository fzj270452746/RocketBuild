//
//  GameServices.swift
//  RocketBuild
//
//  The composition root. Instead of scattered singletons, one GameServices
//  bundle is created at launch and injected downward into scenes and view
//  controllers. Every collaborator is constructed here exactly once.
//

import Foundation

final class GameServices {

    let catalog: TileCatalog
    let geometry: GeometryFactory
    let materials: MaterialFactory
    let particles: ParticleFactory
    let moduleRegistry: ModuleRegistry
    let store: SaveStore
    let progression: Progression
    let audio: AudioService

    init() {
        let materials = MaterialFactory()
        let catalog = TileCatalog()
        let store = SaveStore(catalog: catalog)

        self.materials = materials
        self.catalog = catalog
        self.geometry = GeometryFactory(materials: materials)
        self.particles = ParticleFactory()
        self.moduleRegistry = ModuleRegistry(catalog: catalog)
        self.store = store
        self.progression = Progression(store: store)
        self.audio = AudioService()

        audio.setEnabled(store.data.settings.soundEnabled)
    }
}
