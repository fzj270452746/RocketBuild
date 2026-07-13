//
//  FlightViewController+Loop.swift
//  RocketBuild
//
//  The render-driven game loop: countdown → launch → ascent, plus per-frame
//  module updates, movement, camera framing, fuel burn and HUD refresh. Split
//  from the main controller file to keep each concern readable.
//

import SceneKit
import SpriteKit

extension FlightViewController: SCNSceneRendererDelegate {

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        // Compute a clamped delta so a stall never teleports the rocket.
        if lastTime == 0 { lastTime = time }
        let dt = MathUtil.clamp(Float(time - lastTime), 0, 1.0 / 20.0)
        lastTime = time
        guard !isPaused, !isFinished else { return }

        // Contacts are queued off the physics thread; drain them here.
        drainContacts()

        if !hasLaunched {
            updateCountdown(dt: dt)
        } else {
            step(dt: dt, elapsed: time)
        }

        cameraRig.update(dt: dt, focus: rocket.root.presentation.position)
        refreshHUD()
    }

    // MARK: Launch sequence

    private func updateCountdown(dt: Float) {
        launchCountdownRemaining -= Double(dt)
        let n = Int(ceil(launchCountdownRemaining))
        showCountdown(n)
        if launchCountdownRemaining <= 0 {
            performLaunch()
        }
    }

    private func performLaunch() {
        hasLaunched = true
        cameraRig.set(mode: .boost)
        cameraRig.triggerShake(0.6)
        // Ignition particles at the engine.
        let fire = services.particles.engineFire()
        let smoke = services.particles.smoke()
        let engineNode = SCNNode()
        engineNode.position = SCNVector3(0, -2.6, 0)
        engineNode.addParticleSystem(fire)
        engineNode.addParticleSystem(smoke)
        rocket.root.addChildNode(engineNode)
        // Settle the camera back to normal shortly after liftoff.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.cameraRig.set(mode: .normal)
        }
        hideCountdown()
    }

    // MARK: Per-frame step

    private func step(dt: Float, elapsed: TimeInterval) {
        context.resetTransientRequests()

        // Drive modules; they populate thrust / control / shield etc.
        let ctxComponent = ComponentContext(deltaTime: dt, elapsedTime: elapsed, flight: context)
        _ = ctxComponent
        for module in rocket.modules {
            module.update(deltaTime: Double(dt), context: context)
        }

        // Endless events reshape spawn cadence.
        events.update(dt: Double(dt))

        // Vertical motion: base speed + thrust, scaled by weight and boost.
        let baseSpeed = Float(context.stats.speed) + context.thrust
        let weightPenalty = 1.0 / (1.0 + Float(context.stats.weight) * 0.03)
        var verticalSpeed = baseSpeed * weightPenalty * context.speedMultiplier
        if boostHeld && context.fuel > 0 {
            verticalSpeed *= 1.8
        }
        // Low-gravity style events lighten the climb requirement.
        if let ev = events.active { verticalSpeed *= Float(2 - ev.gravityScale) }

        let climb = verticalSpeed * dt
        worldRoot.position.y -= climb          // world scrolls down = rocket rises
        context.addAltitude(Double(climb) * 3) // altitude in metres (tuned)

        // Fuel burn scales with boost and thrust.
        let burn = Double(dt) * (boostHeld ? 3.2 : 1.4)
        context.consumeFuel(burn)

        // Lateral steering with control responsiveness.
        let control = 6 + context.controlBonus + Float(context.stats.control)
        let k = MathUtil.smoothingFactor(speed: control, dt: dt)
        rocket.root.position.x = MathUtil.lerpf(rocket.root.position.x, targetLateral, k)
        // Bank the rocket into the turn for feel.
        let bank = (targetLateral - rocket.root.position.x)
        rocket.root.eulerAngles.z = MathUtil.lerpf(rocket.root.eulerAngles.z, -bank * 0.15, k)

        // Camera framing follows boost / danger.
        if boostHeld && cameraRig.mode == .normal { cameraRig.set(mode: .boost) }
        if !boostHeld && cameraRig.mode == .boost { cameraRig.set(mode: .normal) }

        streamWorld()
        cullPassed()
        applyMagnet(dt: dt)
        checkEndConditions()
    }

    // MARK: HUD

    private func refreshHUD() {
        let snapshot = HUDSnapshot(
            altitude: context.altitude,
            coins: context.coins,
            fuelFraction: context.maxFuel > 0 ? context.fuel / context.maxFuel : 0,
            shieldFraction: context.stats.shield > 0 ? context.shieldCharge / context.stats.shield : 0,
            multiplier: context.multiplier,
            eventName: currentEventName
        )
        hud.apply(snapshot)
    }

    // MARK: End conditions

    private func checkEndConditions() {
        // The rocket holds station at the origin while the world scrolls, so it
        // never "falls" out of frame — a run ends only when fuel runs dry or the
        // hull is destroyed.
        if !context.isAlive {
            finishRun()
        }
    }

    func finishRun() {
        guard !isFinished else { return }
        isFinished = true
        cameraRig.set(mode: .crash)
        handleEffect(.explosion(rocket.root.presentation.position))
        let result = RunResult(altitude: context.altitude,
                               coins: context.coins,
                               score: context.altitude > 0 ? Int(context.altitude) : 0)
        // Brief slow-mo beat before handing control back.
        scnView.scene?.isPaused = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.delegate?.flightDidEnd(result: result)
        }
    }
}
