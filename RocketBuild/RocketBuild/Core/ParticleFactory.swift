//
//  ParticleFactory.swift
//  RocketBuild
//
//  Every SCNParticleSystem in the game is created here so budgets and colours
//  stay coordinated. Systems are built programmatically (no .scnp assets).
//

import SceneKit
import UIKit

final class ParticleFactory {

    // A soft round sprite reused by most systems, rendered once.
    private lazy var softDot: UIImage = Self.makeSoftDot()

    /// Engine exhaust fire.
    func engineFire() -> SCNParticleSystem {
        let p = base(rate: 220, life: 0.5, size: 0.35)
        p.particleColor = Palette.warning
        p.particleColorVariation = SCNVector4(0.1, 0.2, 0.0, 0.0)
        p.emitterShape = SCNCone(topRadius: 0.05, bottomRadius: 0.25, height: 0.1)
        p.particleVelocity = 6
        p.particleVelocityVariation = 2
        p.spreadingAngle = 8
        p.emittingDirection = SCNVector3(0, -1, 0)
        p.particleSizeVariation = 0.15
        p.blendMode = .additive
        p.isLightingEnabled = false
        return p
    }

    /// Grey launch smoke.
    func smoke() -> SCNParticleSystem {
        let p = base(rate: 90, life: 1.6, size: 0.7)
        p.particleColor = UIColor(white: 0.8, alpha: 0.5)
        p.particleVelocity = 2.4
        p.particleVelocityVariation = 1.2
        p.spreadingAngle = 45
        p.emittingDirection = SCNVector3(0, -1, 0)
        p.particleSizeVariation = 0.4
        p.blendMode = .alpha
        p.dampingFactor = 0.6
        return p
    }

    /// Bright spark burst used on ignition and near-misses.
    func spark() -> SCNParticleSystem {
        let p = base(rate: 400, life: 0.4, size: 0.12)
        p.particleColor = Palette.coin
        p.birthDirection = .random
        p.particleVelocity = 8
        p.particleVelocityVariation = 4
        p.blendMode = .additive
        p.emissionDuration = 0.15
        p.loops = false
        return p
    }

    /// Explosion when a hazard or module is destroyed.
    func explosion() -> SCNParticleSystem {
        let p = base(rate: 900, life: 0.7, size: 0.4)
        p.particleColor = Palette.hullAccent
        p.particleColorVariation = SCNVector4(0.1, 0.3, 0.0, 0.0)
        p.birthDirection = .random
        p.particleVelocity = 12
        p.particleVelocityVariation = 6
        p.blendMode = .additive
        p.emissionDuration = 0.1
        p.loops = false
        return p
    }

    /// Coin pickup burst.
    func coinBurst() -> SCNParticleSystem {
        let p = base(rate: 240, life: 0.5, size: 0.15)
        p.particleColor = Palette.coin
        p.birthDirection = .random
        p.particleVelocity = 5
        p.blendMode = .additive
        p.emissionDuration = 0.1
        p.loops = false
        return p
    }

    /// Continuous star trail streaming behind the rocket.
    func starTrail() -> SCNParticleSystem {
        let p = base(rate: 60, life: 1.0, size: 0.1)
        p.particleColor = Palette.hud
        p.particleVelocity = 1
        p.emittingDirection = SCNVector3(0, -1, 0)
        p.spreadingAngle = 6
        p.blendMode = .additive
        return p
    }

    /// A gentle field halo for the magnet ability.
    func magnetField() -> SCNParticleSystem {
        let p = base(rate: 40, life: 0.8, size: 0.2)
        p.particleColor = Palette.good
        p.emitterShape = SCNSphere(radius: 1.0)
        p.birthLocation = .surface
        p.particleVelocity = 0.4
        p.blendMode = .additive
        return p
    }

    // MARK: - Building blocks

    private func base(rate: CGFloat, life: CGFloat, size: CGFloat) -> SCNParticleSystem {
        let p = SCNParticleSystem()
        p.birthRate = rate
        p.particleLifeSpan = life
        p.particleLifeSpanVariation = life * 0.3
        p.particleSize = size
        p.particleImage = softDot
        p.isLightingEnabled = false
        p.sortingMode = .none
        return p
    }

    private static func makeSoftDot() -> UIImage {
        let side: CGFloat = 64
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { ctx in
            let colors = [UIColor.white.cgColor,
                          UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            guard let gradient = CGGradient(colorsSpace: space, colors: colors,
                                            locations: [0, 1]) else { return }
            let center = CGPoint(x: side / 2, y: side / 2)
            ctx.cgContext.drawRadialGradient(gradient, startCenter: center, startRadius: 0,
                                             endCenter: center, endRadius: side / 2,
                                             options: [])
        }
    }
}
