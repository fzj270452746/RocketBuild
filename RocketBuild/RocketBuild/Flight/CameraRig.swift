//
//  CameraRig.swift
//  RocketBuild
//
//  Owns the camera node and blends between framing modes described in the doc
//  (normal / boost zoom-out / danger shake / crash slow-mo). Kept separate from
//  the scene so the framing logic is testable and swappable.
//

import SceneKit

final class CameraRig {

    enum Mode {
        case normal, boost, danger, crash
    }

    let node = SCNNode()
    private let camera = SCNCamera()
    private(set) var mode: Mode = .normal

    private var shakeRemaining: Float = 0
    private var baseOffset = SCNVector3(0, 2.5, 12)

    init() {
        camera.fieldOfView = 60
        camera.zFar = 400
        camera.wantsHDR = true
        camera.bloomIntensity = 1.1
        camera.bloomThreshold = 0.6
        camera.bloomBlurRadius = 12
        node.camera = camera
        node.position = baseOffset
        node.look(at: SCNVector3(0, 3, 0))
    }

    func set(mode: Mode) {
        guard mode != self.mode else { return }
        self.mode = mode
        switch mode {
        case .normal:
            animateOffset(SCNVector3(0, 2.5, 12), fov: 60, duration: 0.6)
        case .boost:
            animateOffset(SCNVector3(0, 3.0, 16), fov: 72, duration: 0.4)
        case .danger:
            shakeRemaining = 0.4
        case .crash:
            animateOffset(SCNVector3(0, 2.0, 9), fov: 50, duration: 0.5)
        }
    }

    /// Follows the rocket laterally; adds shake while in danger. The rocket
    /// holds station near the origin vertically (the world scrolls past it), so
    /// the camera keeps a fixed height and only eases sideways to track steering.
    func update(dt: Float, focus: SCNVector3) {
        let target = SCNVector3(focus.x * 0.4, baseOffset.y, baseOffset.z)
        let k = MathUtil.smoothingFactor(speed: 6, dt: dt)
        node.position = SCNVector3(
            MathUtil.lerpf(node.position.x, target.x, k),
            MathUtil.lerpf(node.position.y, target.y, k),
            MathUtil.lerpf(node.position.z, target.z, k)
        )

        if shakeRemaining > 0 {
            shakeRemaining -= dt
            let mag = MathUtil.clampf(shakeRemaining / 0.4, 0, 1) * 0.35
            node.position.x += Float.random(in: -mag...mag)
            node.position.y += Float.random(in: -mag...mag)
            if shakeRemaining <= 0 && mode == .danger { set(mode: .normal) }
        }

        // Look slightly above the rocket so the ascent reads with headroom.
        node.look(at: SCNVector3(focus.x * 0.2, focus.y + 3, 0))
    }

    func triggerShake(_ duration: Float = 0.4) {
        shakeRemaining = max(shakeRemaining, duration)
    }

    private func animateOffset(_ offset: SCNVector3, fov: CGFloat, duration: TimeInterval) {
        baseOffset = offset
        SCNTransaction.begin()
        SCNTransaction.animationDuration = duration
        camera.fieldOfView = fov
        SCNTransaction.commit()
    }
}
