//
//  RocketBody.swift
//  RocketBuild
//
//  The assembled rocket: procedural geometry built via the factories, a stack
//  of slot anchor nodes, and the live modules driving abilities. Stats are the
//  sum of the base chassis plus every installed tile's contribution.
//

import SceneKit

/// Describes one physical slot position on the fuselage.
struct SlotAnchor {
    let index: Int
    let node: SCNNode
}

final class RocketBody {

    let root = SCNNode()
    private let geometry: GeometryFactory
    private let materials: MaterialFactory
    private let catalog: TileCatalog

    private(set) var modules: [RocketModule] = []
    private(set) var slotAnchors: [SlotAnchor] = []
    private var moduleNodes: [SCNNode] = []

    /// Aggregated stats after assembly.
    private(set) var stats: RocketStats = .baseChassis
    private var fuelBonus: Double = 0

    let bodyRadius: CGFloat = 0.6
    private let slotSpacing: CGFloat = 0.95

    init(geometry: GeometryFactory, materials: MaterialFactory, catalog: TileCatalog) {
        self.geometry = geometry
        self.materials = materials
        self.catalog = catalog
    }

    /// Effective max fuel including bonuses from fuel modules.
    var maxFuel: Double { stats.fuel + fuelBonus }

    // MARK: Building

    /// Builds fuselage + slot anchors for a configuration, then installs modules
    /// resolved from the given inventory using the registry.
    func build(configuration: RocketConfiguration,
               inventory: [UUID: TileInstance],
               registry: ModuleRegistry) {
        reset()
        buildChassis(slotCount: configuration.slotCount)

        for (slotIndex, maybeID) in configuration.slots.enumerated() {
            guard let id = maybeID, let instance = inventory[id],
                  let def = catalog.definition(instance.definitionID),
                  let module = registry.makeModule(for: instance) else { continue }

            attachTileNode(def: def, instance: instance, at: slotIndex)
            module.install(on: self)
            modules.append(module)
            // Higher-quality tiles contribute proportionally more (weight aside).
            stats += def.statContribution.scaledBenefits(by: instance.quality.powerScale)
        }
    }

    private func buildChassis(slotCount: Int) {
        let bodyHeight = CGFloat(slotCount) * slotSpacing + 0.6

        // Fuselage centred on the origin.
        let bodyNode = SCNNode(geometry: geometry.rocketBody(height: bodyHeight, radius: bodyRadius))
        bodyNode.name = "fuselage"
        root.addChildNode(bodyNode)

        // Nose cone on top.
        let nose = SCNNode(geometry: geometry.noseCone(radius: bodyRadius, height: 1.2))
        nose.position = SCNVector3(0, Float(bodyHeight / 2 + 0.6), 0)
        root.addChildNode(nose)

        // Engine bell at the bottom.
        let engine = SCNNode(geometry: geometry.engineBell(topRadius: bodyRadius * 0.5,
                                                            bottomRadius: bodyRadius,
                                                            height: 0.9))
        engine.position = SCNVector3(0, Float(-bodyHeight / 2 - 0.45), 0)
        engine.name = "engine"
        root.addChildNode(engine)

        // Fins around the base.
        for i in 0..<3 {
            let fin = SCNNode(geometry: geometry.fin(width: 0.5, height: 1.0, thickness: 0.1))
            let angle = Float(i) * (2 * .pi / 3)
            fin.position = SCNVector3(cos(angle) * Float(bodyRadius),
                                      Float(-bodyHeight / 2 + 0.2),
                                      sin(angle) * Float(bodyRadius))
            fin.eulerAngles.y = -angle
            root.addChildNode(fin)
        }

        // Slot anchors distributed from just below the nose downwards, on +Z.
        let top = Float(bodyHeight / 2 - 0.5)
        for i in 0..<slotCount {
            let anchor = SCNNode()
            let y = top - Float(i) * Float(slotSpacing)
            anchor.position = SCNVector3(0, y, Float(bodyRadius) + 0.18)
            root.addChildNode(anchor)
            slotAnchors.append(SlotAnchor(index: i, node: anchor))
        }
    }

    private func attachTileNode(def: TileDefinition, instance: TileInstance, at slotIndex: Int) {
        guard slotAnchors.indices.contains(slotIndex) else { return }
        let face = materials.tileFaceImage(glyph: def.glyph, suit: def.suit,
                                           quality: instance.quality,
                                           cacheKey: def.faceCacheKey + "_\(instance.quality.rawValue)")
        let tileGeo = geometry.mahjongTile(size: 0.55, faceImage: face, quality: instance.quality)
        let node = SCNNode(geometry: tileGeo)
        node.name = "module_\(slotIndex)"
        slotAnchors[slotIndex].node.addChildNode(node)
        moduleNodes.append(node)
    }

    // MARK: Module queries

    func registerFuelBonus(_ amount: Double) { fuelBonus += amount }

    func modules<T: RocketModule>(ofType type: T.Type) -> [T] {
        modules.compactMap { $0 as? T }
    }

    /// Damage a random functional module (used on collision).
    func damageRandomModule(_ amount: Double) {
        let functional = modules.filter { $0.isFunctional }
        guard let target = functional.randomElement() else { return }
        target.takeDamage(amount)
    }

    // MARK: Lifecycle

    private func reset() {
        modules.forEach { $0.remove() }
        modules.removeAll()
        moduleNodes.forEach { $0.removeFromParentNode() }
        moduleNodes.removeAll()
        slotAnchors.removeAll()
        root.childNodes.forEach { $0.removeFromParentNode() }
        stats = .baseChassis
        fuelBonus = 0
    }
}
