//
//  GeometryFactory.swift
//  RocketBuild
//
//  All SceneKit primitives are born here. Gameplay code never allocates an
//  SCNBox / SCNSphere directly — it asks the factory for a named piece so
//  proportions and rounding stay consistent across the game.
//

import SceneKit

/// Instances are cheap; each scene owns one so there is no global state.
final class GeometryFactory {

    private let materials: MaterialFactory

    init(materials: MaterialFactory) {
        self.materials = materials
    }

    // MARK: Rocket

    /// The central fuselage the modules attach to.
    func rocketBody(height: CGFloat, radius: CGFloat) -> SCNGeometry {
        let g = SCNCylinder(radius: radius, height: height)
        g.radialSegmentCount = 24
        g.materials = [materials.hull()]
        return g
    }

    /// Rounded nose cone.
    func noseCone(radius: CGFloat, height: CGFloat) -> SCNGeometry {
        let g = SCNCone(topRadius: 0, bottomRadius: radius, height: height)
        g.radialSegmentCount = 24
        g.materials = [materials.accentHull()]
        return g
    }

    /// Engine bell at the tail.
    func engineBell(topRadius: CGFloat, bottomRadius: CGFloat, height: CGFloat) -> SCNGeometry {
        let g = SCNCone(topRadius: topRadius, bottomRadius: bottomRadius, height: height)
        g.radialSegmentCount = 24
        g.materials = [materials.engine()]
        return g
    }

    /// A capsule fin.
    func fin(width: CGFloat, height: CGFloat, thickness: CGFloat) -> SCNGeometry {
        let g = SCNBox(width: width, height: height, length: thickness, chamferRadius: thickness * 0.4)
        g.materials = [materials.accentHull()]
        return g
    }

    // MARK: Mahjong tile

    /// A rounded mahjong tile used both as an installed module and as a
    /// draggable inventory piece. Face material carries the printed glyph.
    func mahjongTile(size: CGFloat, faceImage: UIImage, quality: TileQuality) -> SCNGeometry {
        let g = SCNBox(width: size, height: size * 1.35, length: size * 0.4,
                       chamferRadius: size * 0.12)
        // SCNBox material order is front(+Z), right(+X), back(-Z), left(-X),
        // top(+Y), bottom(-Y). The printed glyph must go on the front face
        // (index 0) so it faces the flight camera, not the top (index 4).
        let ivory = materials.tileIvory()
        let face = materials.tileFace(image: faceImage, quality: quality)
        g.materials = [face, ivory, ivory, ivory, ivory, ivory]
        return g
    }

    // MARK: Hazards

    func asteroid(radius: CGFloat) -> SCNGeometry {
        let g = SCNSphere(radius: radius)
        g.segmentCount = 12
        g.materials = [materials.rock()]
        return g
    }

    func satelliteCore(size: CGFloat) -> SCNGeometry {
        let g = SCNBox(width: size, height: size, length: size, chamferRadius: size * 0.15)
        g.materials = [materials.engine()]
        return g
    }

    func satellitePanel(width: CGFloat, height: CGFloat) -> SCNGeometry {
        let g = SCNBox(width: width, height: height, length: width * 0.05, chamferRadius: 0.01)
        g.materials = [materials.solarPanel()]
        return g
    }

    func debris(size: CGFloat) -> SCNGeometry {
        let g = SCNBox(width: size, height: size * 0.6, length: size * 0.8, chamferRadius: size * 0.1)
        g.materials = [materials.rock()]
        return g
    }

    func blackHoleRing(radius: CGFloat) -> SCNGeometry {
        let g = SCNTorus(ringRadius: radius, pipeRadius: radius * 0.22)
        g.ringSegmentCount = 32
        g.materials = [materials.voidRing()]
        return g
    }

    func laserBeam(length: CGFloat, radius: CGFloat) -> SCNGeometry {
        let g = SCNCylinder(radius: radius, height: length)
        g.materials = [materials.laser()]
        return g
    }

    // MARK: Pickups

    func crystal(radius: CGFloat) -> SCNGeometry {
        let g = SCNSphere(radius: radius)
        g.segmentCount = 8
        g.materials = [materials.crystal()]
        return g
    }

    func capsule(radius: CGFloat, height: CGFloat) -> SCNGeometry {
        let g = SCNCapsule(capRadius: radius, height: height)
        g.materials = [materials.emissive(Palette.good)]
        return g
    }

    func coin(radius: CGFloat) -> SCNGeometry {
        let g = SCNCylinder(radius: radius, height: radius * 0.25)
        g.radialSegmentCount = 16
        g.materials = [materials.emissive(Palette.coin)]
        return g
    }

    // MARK: Environment

    func launchPad(radius: CGFloat) -> SCNGeometry {
        let g = SCNCylinder(radius: radius, height: 0.4)
        g.materials = [materials.engine()]
        return g
    }
}
