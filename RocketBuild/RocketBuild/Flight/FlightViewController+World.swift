//
//  FlightViewController+World.swift
//  RocketBuild
//
//  World streaming (hazards & pickups), magnet attraction, physics contact
//  handling, ability effects and the countdown overlay. These are the systems
//  that make the endless ascent feel alive.
//

import SceneKit
import SpriteKit
import UIKit

extension FlightViewController: SCNPhysicsContactDelegate {

    // The rocket's current world-space height (world scrolls, rocket stays near origin).
    private var worldScroll: Float { -worldRoot.position.y }

    // MARK: Streaming

    func streamWorld() {
        let horizon = worldScroll + 90 // spawn this far ahead of the rocket
        let diff = context.difficulty
        let eventSpawnScale = events.active?.spawnRateMultiplier ?? 1
        let hazardBias = events.active?.hazardBias ?? 1
        let coinBias = events.active?.coinBias ?? 1

        // Hazards.
        let hazardGap = Float(6 * diff.spawnScale / eventSpawnScale)
        while nextHazardHeight < horizon {
            if Double.random(in: 0...1) < 0.9 * hazardBias {
                spawnHazard(atHeight: nextHazardHeight, difficulty: diff)
            }
            nextHazardHeight += max(2.5, hazardGap)
        }

        // Pickups.
        let pickupGap = Float(5.5 / max(0.5, coinBias))
        while nextPickupHeight < horizon {
            spawnPickup(atHeight: nextPickupHeight)
            nextPickupHeight += max(2.5, pickupGap)
        }
    }

    private func spawnHazard(atHeight h: Float, difficulty: DifficultyBand) {
        let kind = HazardKind.allCases.randomElement() ?? .asteroid
        let entity = spawner.makeHazard(kind: kind, difficulty: difficulty)
        entity.node.position = SCNVector3(Float.random(in: -6...6), h, Float.random(in: -1...1))
        hazardLayer.addChildNode(entity.node)
        liveHazards.append(entity)
    }

    private func spawnPickup(atHeight h: Float) {
        let kind = spawner.randomPickupKind()
        let entity = spawner.makePickup(kind: kind)
        entity.node.position = SCNVector3(Float.random(in: -6...6), h, Float.random(in: -1...1))
        pickupLayer.addChildNode(entity.node)
        livePickups.append(entity)
    }

    /// Removes entities that have dropped well below the rocket.
    func cullPassed() {
        let cutoff = worldScroll - 20
        liveHazards.removeAll { entity in
            if entity.node.position.y < cutoff { entity.destroy(); return true }
            // Apply drift each cull pass (cheap, frame-rate independent enough).
            if let h = entity.component(HazardComponent.self) {
                entity.node.position.x += h.drift.x * 0.05
            }
            return false
        }
        livePickups.removeAll { entity in
            if entity.node.position.y < cutoff { entity.destroy(); return true }
            return false
        }
    }

    // MARK: Magnet

    func applyMagnet(dt: Float) {
        let radius = Float(context.magnetRadius)
        guard radius > 0.1 else { return }
        let rocketPos = SCNVector3(rocket.root.position.x, worldScroll, 0)
        for entity in livePickups {
            let p = entity.node.position
            let d = p.distance(to: rocketPos)
            if d < radius {
                // Pull toward the rocket.
                let dir = (rocketPos - p) * (dt * 4)
                entity.node.position = p + dir
            }
        }
    }

    // MARK: Physics contacts

    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        // Contact delegate runs on the physics thread; queue for the main loop.
        pendingContacts.append(contact)
    }

    func drainContacts() {
        let contacts = pendingContacts
        pendingContacts.removeAll()
        for contact in contacts { resolveContact(contact) }
    }

    private func resolveContact(_ contact: SCNPhysicsContact) {
        let nodes = [contact.nodeA, contact.nodeB]
        guard nodes.contains(where: { $0.name == "rocket" }) else { return }
        let other = nodes.first { $0.name != "rocket" }
        guard let other else { return }

        if let hazardEntity = liveHazards.first(where: { $0.node === other || other.isDescendant(of: $0.node) }) {
            hitHazard(hazardEntity)
        } else if let pickupEntity = livePickups.first(where: { $0.node === other }) {
            collectPickup(pickupEntity)
        }
    }

    private func hitHazard(_ entity: Entity) {
        guard let hazard = entity.component(HazardComponent.self) else { return }
        context.damageHull(hazard.damage)
        rocket.damageRandomModule(hazard.damage * 0.6)
        cameraRig.set(mode: .danger)
        handleEffect(.explosion(entity.node.position))
        entity.destroy()
        liveHazards.removeAll { $0 === entity }
        services.audio.play(.explosion)
    }

    private func collectPickup(_ entity: Entity) {
        guard let pickup = entity.component(PickupComponent.self) else { return }
        applyPickupReward(pickup.kind)
        handleEffect(.coinBurst(entity.node.position))
        entity.destroy()
        livePickups.removeAll { $0 === entity }
        // A clean pickup counts as a perfect dodge for combo purposes.
        context.registerDodge(perfect: pickup.kind == .goldenMahjong)
    }

    private func applyPickupReward(_ kind: PickupKind) {
        switch kind {
        case .coin:
            context.addCoins(1); services.audio.play(.coin)
        case .energyCrystal:
            context.addEnergy(20); services.audio.play(.coin)
        case .fuelCapsule:
            context.refuel(25); services.audio.play(.coin)
        case .mysteryBox:
            context.addCoins(Int.random(in: 3...10)); context.refuel(10)
            services.audio.play(.coin)
        case .goldenMahjong:
            context.addCoins(15)
            services.progression.unlockRandomTile(from: services.catalog)
            services.audio.play(.magnet)
        }
    }

    // MARK: Effects

    func handleEffect(_ effect: FlightEffect) {
        switch effect {
        case .shieldRipple:
            services.audio.play(.shield)
        case .boostFlash:
            services.audio.play(.launch)
        case .explosion(let pos):
            emit(services.particles.explosion(), at: pos, in: hazardLayer)
        case .coinBurst(let pos):
            emit(services.particles.coinBurst(), at: pos, in: pickupLayer)
        }
    }

    func detonate(radius: Float) {
        // Clear nearby hazards (Red Dragon explosion ability).
        let origin = SCNVector3(rocket.root.position.x, worldScroll, 0)
        let toRemove = liveHazards.filter { $0.node.position.distance(to: origin) < radius }
        for e in toRemove {
            handleEffect(.explosion(e.node.position))
            e.destroy()
        }
        liveHazards.removeAll { entity in toRemove.contains { $0 === entity } }
        cameraRig.triggerShake(0.3)
        services.audio.play(.explosion)
    }

    private func emit(_ system: SCNParticleSystem, at pos: SCNVector3, in layer: SCNNode) {
        let node = SCNNode()
        node.position = pos
        node.addParticleSystem(system)
        layer.addChildNode(node)
        node.runAction(.sequence([.wait(duration: 1.2), .removeFromParentNode()]))
    }

    // MARK: Countdown overlay

    func showCountdown(_ n: Int) {
        let name = "countdown"
        if let existing = hud.childNode(withName: name) as? SKLabelNode {
            existing.text = n > 0 ? "\(n)" : "GO!"
            return
        }
        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.name = name
        label.fontSize = 96
        label.fontColor = Palette.warning
        label.position = CGPoint(x: hud.size.width / 2, y: hud.size.height / 2)
        label.text = "\(n)"
        hud.addChild(label)
    }

    func hideCountdown() {
        guard let label = hud.childNode(withName: "countdown") else { return }
        label.run(.sequence([.scale(to: 1.6, duration: 0.2),
                             .fadeOut(withDuration: 0.2),
                             .removeFromParent()]))
    }
}

private extension SCNNode {
    func isDescendant(of node: SCNNode) -> Bool {
        var current: SCNNode? = parent
        while let c = current {
            if c === node { return true }
            current = c.parent
        }
        return false
    }
}
