//
//  Environment.swift
//  RocketBuild
//
//  Builds the static-ish world dressing: gradient background, star field, soft
//  lighting and the launch pad. Grouped under a single root node so it can be
//  parented into the flight scene's WorldRoot.
//

import SceneKit

final class Environment {

    let root = SCNNode()
    private let starField = SCNNode()

    private let geometry: GeometryFactory
    private let materials: MaterialFactory

    init(geometry: GeometryFactory, materials: MaterialFactory) {
        self.geometry = geometry
        self.materials = materials
        build()
    }

    private func build() {
        addLighting()
        addStars(count: 220)
        addLaunchPad()
    }

    private func addLighting() {
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 500
        ambient.light?.color = UIColor(white: 0.7, alpha: 1)
        root.addChildNode(ambient)

        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.intensity = 900
        key.light?.castsShadow = true
        key.light?.shadowMode = .deferred
        key.light?.shadowRadius = 8
        key.light?.shadowColor = UIColor(white: 0, alpha: 0.25)
        key.eulerAngles = SCNVector3(-Float.pi / 4, Float.pi / 6, 0)
        root.addChildNode(key)
    }

    private func addStars(count: Int) {
        // Billboarded planes scattered on a far shell behind the play space.
        let starMaterial = materials.emissive(.white, intensity: 1.0)
        for _ in 0..<count {
            let plane = SCNPlane(width: 0.3, height: 0.3)
            plane.materials = [starMaterial]
            let star = SCNNode(geometry: plane)
            let constraint = SCNBillboardConstraint()
            star.constraints = [constraint]
            star.position = SCNVector3(Float.random(in: -40...40),
                                       Float.random(in: -20...260),
                                       Float.random(in: -60 ... -25))
            star.opacity = CGFloat.random(in: 0.3...1.0)
            let s = Float.random(in: 0.4...1.4)
            star.scale = SCNVector3(s, s, s)
            starField.addChildNode(star)
        }
        root.addChildNode(starField)
    }

    private func addLaunchPad() {
        let pad = SCNNode(geometry: geometry.launchPad(radius: 2.2))
        pad.position = SCNVector3(0, -3.2, 0)
        pad.name = "launchPad"
        root.addChildNode(pad)
    }

    /// Applies a vertical gradient as the scene background.
    func applyBackground(to scene: SCNScene, size: CGSize) {
        let layer = CAGradientLayer()
        layer.frame = CGRect(origin: .zero, size: size)
        layer.colors = [Palette.spaceTop.cgColor, Palette.spaceBottom.cgColor]
        layer.startPoint = CGPoint(x: 0.5, y: 0)
        layer.endPoint = CGPoint(x: 0.5, y: 1)

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in layer.render(in: ctx.cgContext) }
        scene.background.contents = image
    }
}
