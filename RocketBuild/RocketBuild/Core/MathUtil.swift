//
//  MathUtil.swift
//  RocketBuild
//
//  Lightweight math helpers shared by gameplay systems. Kept free of any
//  scene state so callers can be tested in isolation.
//

import CoreGraphics
import SceneKit
import simd

enum MathUtil {

    /// Linear interpolation between two floats.
    static func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * clamp(t, 0, 1)
    }

    static func lerpf(_ a: Float, _ b: Float, _ t: Float) -> Float {
        a + (b - a) * clampf(t, 0, 1)
    }

    /// Frame-rate independent smoothing factor. `speed` is how fast we
    /// approach the target (per second); higher converges quicker.
    static func smoothingFactor(speed: Float, dt: Float) -> Float {
        1 - expf(-speed * max(dt, 0))
    }

    static func clamp<T: Comparable>(_ value: T, _ lower: T, _ upper: T) -> T {
        min(max(value, lower), upper)
    }

    static func clampf(_ value: Float, _ lower: Float, _ upper: Float) -> Float {
        Swift.min(Swift.max(value, lower), upper)
    }

    /// Maps `value` from the input range into the output range, clamped.
    static func remap(_ value: Float, _ inMin: Float, _ inMax: Float,
                      _ outMin: Float, _ outMax: Float) -> Float {
        guard inMax != inMin else { return outMin }
        let t = clampf((value - inMin) / (inMax - inMin), 0, 1)
        return outMin + (outMax - outMin) * t
    }

    static func randomUnit() -> Float { Float.random(in: 0...1) }

    static func randomSigned() -> Float { Float.random(in: -1...1) }
}

extension SCNVector3 {
    static func + (l: SCNVector3, r: SCNVector3) -> SCNVector3 {
        SCNVector3(l.x + r.x, l.y + r.y, l.z + r.z)
    }
    static func - (l: SCNVector3, r: SCNVector3) -> SCNVector3 {
        SCNVector3(l.x - r.x, l.y - r.y, l.z - r.z)
    }
    static func * (l: SCNVector3, s: Float) -> SCNVector3 {
        SCNVector3(l.x * s, l.y * s, l.z * s)
    }

    var length: Float { simd_length(simd_float3(x, y, z)) }

    func distance(to other: SCNVector3) -> Float {
        (self - other).length
    }
}
