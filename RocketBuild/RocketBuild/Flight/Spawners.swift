//
//  Spawners.swift
//  RocketBuild
//
//  Builds hazard and pickup entities via the factories and streams them into
//  the world ahead of the rocket. Spawn cadence scales with the difficulty band
//  so higher altitude gets busier, matching the design's altitude table.
//

import SceneKit

enum HazardKind: CaseIterable {
    case asteroid, satellite, debris, blackHole, laserGate, lightningCloud
}

enum PickupKind: CaseIterable {
    case energyCrystal, fuelCapsule, coin, goldenMahjong, mysteryBox

    /// Relative weights for random selection (coins are common).
    var weight: Double {
        switch self {
        case .coin: return 5
        case .energyCrystal: return 3
        case .fuelCapsule: return 2
        case .mysteryBox: return 1
        case .goldenMahjong: return 0.4
        }
    }
}

/// Component that drifts a hazard and, for some kinds, rotates or wanders.
final class HazardComponent: Component {
    let kind: HazardKind
    var damage: Double
    var drift: SCNVector3
    private var wanderPhase: Float = Float.random(in: 0...(2 * .pi))

    init(kind: HazardKind, damage: Double, drift: SCNVector3) {
        self.kind = kind
        self.damage = damage
        self.drift = drift
    }

    func update(_ ctx: ComponentContext) {}
}

/// Component tagging a pickup and how it rewards the player.
final class PickupComponent: Component {
    let kind: PickupKind
    init(kind: PickupKind) { self.kind = kind }
    func update(_ ctx: ComponentContext) {}
}

/// Produces hazards and pickups. Holds no global state; the flight scene owns
/// one instance and feeds it the world layers to attach into.
final class Spawner {

    private let geometry: GeometryFactory
    private let materials: MaterialFactory

    init(geometry: GeometryFactory, materials: MaterialFactory) {
        self.geometry = geometry
        self.materials = materials
    }

    // MARK: Hazards

    func makeHazard(kind: HazardKind, difficulty: DifficultyBand) -> Entity {
        let entity: Entity
        switch kind {
        case .asteroid:        entity = makeAsteroid()
        case .satellite:       entity = makeSatellite()
        case .debris:          entity = makeDebris()
        case .blackHole:       entity = makeBlackHole()
        case .laserGate:       entity = makeLaserGate()
        case .lightningCloud:  entity = makeLightningCloud()
        }
        return entity
    }

    private func physicsHazard(_ node: SCNNode, radius: CGFloat) {
        let body = SCNPhysicsBody(type: .kinematic, shape:
            SCNPhysicsShape(geometry: SCNSphere(radius: radius), options: nil))
        body.categoryBitMask = PhysicsCategory.hazard
        body.contactTestBitMask = PhysicsCategory.rocket
        body.collisionBitMask = 0
        node.physicsBody = body
    }

    private func makeAsteroid() -> Entity {
        let r = CGFloat.random(in: 0.5...1.4)
        let node = SCNNode(geometry: geometry.asteroid(radius: r))
        node.name = "hazard"
        physicsHazard(node, radius: r)
        let e = Entity(node: node)
        node.runAction(.repeatForever(.rotateBy(x: .random(in: -1...1), y: .random(in: -1...1),
                                                z: 0, duration: 3)))
        e.add(HazardComponent(kind: .asteroid, damage: 22,
                              drift: SCNVector3(Float.random(in: -0.6...0.6), 0, 0)))
        return e
    }

    private func makeSatellite() -> Entity {
        let node = SCNNode(geometry: geometry.satelliteCore(size: 0.6))
        node.name = "hazard"
        // Two solar panels.
        for side in [-1.0, 1.0] {
            let panel = SCNNode(geometry: geometry.satellitePanel(width: 0.9, height: 0.4))
            panel.position = SCNVector3(Float(side) * 0.75, 0, 0)
            node.addChildNode(panel)
        }
        physicsHazard(node, radius: 1.1)
        node.runAction(.repeatForever(.rotateBy(x: 0, y: 0, z: .pi * 2, duration: 6)))
        let e = Entity(node: node)
        e.add(HazardComponent(kind: .satellite, damage: 28, drift: SCNVector3(0, 0, 0)))
        return e
    }

    private func makeDebris() -> Entity {
        let node = SCNNode()
        node.name = "hazard"
        // A dense little cluster.
        for _ in 0..<Int.random(in: 3...5) {
            let s = CGFloat.random(in: 0.15...0.3)
            let bit = SCNNode(geometry: geometry.debris(size: s))
            bit.position = SCNVector3(Float.random(in: -0.5...0.5),
                                      Float.random(in: -0.5...0.5),
                                      Float.random(in: -0.3...0.3))
            node.addChildNode(bit)
        }
        physicsHazard(node, radius: 0.6)
        let e = Entity(node: node)
        e.add(HazardComponent(kind: .debris, damage: 12,
                              drift: SCNVector3(Float.random(in: -0.3...0.3), 0, 0)))
        return e
    }

    private func makeBlackHole() -> Entity {
        let node = SCNNode(geometry: geometry.blackHoleRing(radius: 1.0))
        node.name = "hazard"
        // Dark core.
        let core = SCNNode(geometry: geometry.asteroid(radius: 0.7))
        core.geometry?.firstMaterial = materials.matte(.black)
        node.addChildNode(core)
        physicsHazard(node, radius: 0.7)
        node.runAction(.repeatForever(.rotateBy(x: 0, y: 0, z: .pi * 2, duration: 4)))
        let e = Entity(node: node)
        e.add(HazardComponent(kind: .blackHole, damage: 30, drift: SCNVector3(0, 0, 0)))
        return e
    }

    private func makeLaserGate() -> Entity {
        let node = SCNNode(geometry: geometry.laserBeam(length: 9, radius: 0.12))
        node.name = "hazard"
        node.eulerAngles.z = .pi / 2 // horizontal beam
        physicsHazard(node, radius: 0.4)
        // Periodic opening: fade the beam on and off.
        let pulse = SCNAction.sequence([
            .fadeOpacity(to: 0.1, duration: 1.0),
            .fadeOpacity(to: 1.0, duration: 1.0),
        ])
        node.runAction(.repeatForever(pulse))
        let e = Entity(node: node)
        e.add(HazardComponent(kind: .laserGate, damage: 26, drift: SCNVector3(0, 0, 0)))
        return e
    }

    private func makeLightningCloud() -> Entity {
        let node = SCNNode(geometry: geometry.asteroid(radius: 1.0))
        node.geometry?.firstMaterial = materials.emissive(
            UIColor(red: 0.6, green: 0.7, blue: 1.0, alpha: 0.5), intensity: 0.6)
        node.opacity = 0.6
        node.name = "hazard"
        physicsHazard(node, radius: 1.0)
        // Random strikes: flash intensity.
        let strike = SCNAction.sequence([
            .wait(duration: .random(in: 0.6...1.4)),
            .fadeOpacity(to: 1.0, duration: 0.08),
            .fadeOpacity(to: 0.5, duration: 0.2),
        ])
        node.runAction(.repeatForever(strike))
        let e = Entity(node: node)
        e.add(HazardComponent(kind: .lightningCloud, damage: 34, drift: SCNVector3(0, 0, 0)))
        return e
    }

    // MARK: Pickups

    func makePickup(kind: PickupKind) -> Entity {
        let node: SCNNode
        switch kind {
        case .coin:
            node = SCNNode(geometry: geometry.coin(radius: 0.28))
            node.eulerAngles.x = .pi / 2
        case .energyCrystal:
            node = SCNNode(geometry: geometry.crystal(radius: 0.32))
        case .fuelCapsule:
            node = SCNNode(geometry: geometry.capsule(radius: 0.22, height: 0.7))
        case .mysteryBox:
            node = SCNNode(geometry: geometry.satelliteCore(size: 0.5))
            node.geometry?.firstMaterial = materials.emissive(Palette.hud, intensity: 0.8)
        case .goldenMahjong:
            let face = materials.tileFaceImage(glyph: "金", suit: .honor, quality: .gold,
                                               cacheKey: "golden_pickup")
            node = SCNNode(geometry: geometry.mahjongTile(size: 0.5, faceImage: face, quality: .gold))
        }
        node.name = "pickup"

        let body = SCNPhysicsBody(type: .kinematic, shape:
            SCNPhysicsShape(geometry: SCNSphere(radius: 0.4), options: nil))
        body.categoryBitMask = PhysicsCategory.pickup
        body.contactTestBitMask = PhysicsCategory.rocket
        body.collisionBitMask = 0
        node.physicsBody = body
        node.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 2)))

        let e = Entity(node: node)
        e.add(PickupComponent(kind: kind))
        return e
    }

    /// Weighted-random pickup kind selection.
    func randomPickupKind() -> PickupKind {
        let all = PickupKind.allCases
        let total = all.reduce(0) { $0 + $1.weight }
        var roll = Double.random(in: 0..<total)
        for k in all {
            if roll < k.weight { return k }
            roll -= k.weight
        }
        return .coin
    }
}
