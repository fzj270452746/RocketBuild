//
//  MaterialFactory.swift
//  RocketBuild
//
//  Produces the procedural materials used throughout the game. The tile face
//  glyphs are rendered here into UIImages so we never ship texture assets.
//

import SceneKit
import UIKit

final class MaterialFactory {

    // Faces are cached by cache-key because the same glyph appears on many tiles.
    private var faceCache: [String: UIImage] = [:]

    // MARK: Rocket

    func hull() -> SCNMaterial { metal(Palette.hull, roughness: 0.35) }
    func accentHull() -> SCNMaterial { metal(Palette.hullAccent, roughness: 0.3) }
    func engine() -> SCNMaterial { metal(Palette.engineMetal, roughness: 0.2, metalness: 0.9) }

    // MARK: Hazards / pickups

    func rock() -> SCNMaterial { matte(UIColor(red: 0.42, green: 0.38, blue: 0.44, alpha: 1)) }
    func solarPanel() -> SCNMaterial { metal(UIColor(red: 0.20, green: 0.34, blue: 0.62, alpha: 1), roughness: 0.1, metalness: 0.8) }
    func crystal() -> SCNMaterial { emissive(Palette.hud, intensity: 1.4) }
    func laser() -> SCNMaterial { emissive(UIColor(red: 1.0, green: 0.25, blue: 0.35, alpha: 1), intensity: 2.0) }
    func voidRing() -> SCNMaterial { emissive(UIColor(red: 0.55, green: 0.25, blue: 0.95, alpha: 1), intensity: 1.6) }

    // MARK: Generic

    func emissive(_ color: UIColor, intensity: CGFloat = 1.0) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .constant
        m.diffuse.contents = color
        m.emission.contents = color
        m.emission.intensity = intensity
        return m
    }

    func metal(_ color: UIColor, roughness: CGFloat, metalness: CGFloat = 0.6) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = color
        m.roughness.contents = roughness
        m.metalness.contents = metalness
        return m
    }

    func matte(_ color: UIColor) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = color
        m.roughness.contents = 0.9
        m.metalness.contents = 0.0
        return m
    }

    // MARK: Mahjong tile

    /// The ivory sides / back of a tile.
    func tileIvory() -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = UIColor(red: 0.96, green: 0.95, blue: 0.90, alpha: 1)
        m.roughness.contents = 0.5
        m.metalness.contents = 0.0
        return m
    }

    /// The printed front face with a quality glow border.
    func tileFace(image: UIImage, quality: TileQuality) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = image
        m.roughness.contents = 0.4
        // Gold+ tiles get a subtle emissive glow so rarity reads at a glance.
        if quality != .common {
            m.emission.contents = image
            m.emission.intensity = quality == .gold ? 0.5 : 0.28
        }
        return m
    }

    // MARK: Tile face rendering

    /// Renders a mahjong glyph onto an ivory tile face. Cached per key. The face
    /// gets a soft ivory gradient, an engraved double border and a quality glow
    /// ring; multi-character glyphs (e.g. "五萬") are stacked so they read like a
    /// real printed tile rather than one cramped label.
    func tileFaceImage(glyph: String, suit: TileSuit, quality: TileQuality,
                       cacheKey: String) -> UIImage {
        if let cached = faceCache[cacheKey] { return cached }

        let w: CGFloat = 256
        let h: CGFloat = w * 1.35
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h))
        let image = renderer.image { rendererCtx in
            let ctx = rendererCtx.cgContext
            let rect = CGRect(x: 0, y: 0, width: w, height: h)

            // Ivory base with a soft vertical gradient for a rounded, lit look.
            let bodyPath = UIBezierPath(roundedRect: rect.insetBy(dx: 6, dy: 6), cornerRadius: 34)
            ctx.saveGState()
            bodyPath.addClip()
            let top = UIColor(red: 0.99, green: 0.98, blue: 0.94, alpha: 1)
            let bottom = UIColor(red: 0.90, green: 0.88, blue: 0.80, alpha: 1)
            let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: [top.cgColor, bottom.cgColor] as CFArray,
                                  locations: [0, 1])!
            ctx.drawLinearGradient(grad, start: .zero, end: CGPoint(x: 0, y: h), options: [])
            ctx.restoreGState()

            // Engraved recessed panel: a darker outer ring + inset highlight so
            // the printed area looks pressed into the ivory.
            let outer = rect.insetBy(dx: 20, dy: 20)
            let outerPath = UIBezierPath(roundedRect: outer, cornerRadius: 26)
            UIColor(white: 0.55, alpha: 0.55).setStroke()
            outerPath.lineWidth = 3
            outerPath.stroke()

            let inner = rect.insetBy(dx: 26, dy: 26)
            let innerPath = UIBezierPath(roundedRect: inner, cornerRadius: 22)
            UIColor(white: 1.0, alpha: 0.9).setStroke()
            innerPath.lineWidth = 2
            innerPath.stroke()

            // Rarity glow ring (subtle for common, brighter for higher tiers).
            let border = Palette.quality(quality)
            let glowRect = rect.insetBy(dx: 12, dy: 12)
            let glowPath = UIBezierPath(roundedRect: glowRect, cornerRadius: 30)
            border.withAlphaComponent(quality == .common ? 0.35 : 0.95).setStroke()
            glowPath.lineWidth = quality == .common ? 6 : 10
            glowPath.stroke()

            // Glyph: stack characters vertically (数字 above 花色) when there are
            // two, so "五萬" reads as a proper tile face.
            let color = Palette.suit(suit)
            let chars = Array(glyph)
            let printArea = rect.insetBy(dx: 34, dy: 40)
            if chars.count >= 2 {
                let line1 = String(chars[0])
                let line2 = String(chars[1...].map { $0 })
                drawGlyphLine(line1, in: CGRect(x: printArea.minX, y: printArea.minY,
                                                width: printArea.width, height: printArea.height * 0.52),
                              fontSize: w * 0.5, color: color)
                drawGlyphLine(line2, in: CGRect(x: printArea.minX, y: printArea.midY - printArea.height * 0.02,
                                                width: printArea.width, height: printArea.height * 0.5),
                              fontSize: w * 0.44, color: color)
            } else {
                drawGlyphLine(glyph, in: printArea, fontSize: w * 0.68, color: color)
            }
        }
        faceCache[cacheKey] = image
        return image
    }

    /// Draws one centered glyph line with a faint shadow for depth.
    private func drawGlyphLine(_ text: String, in rect: CGRect, fontSize: CGFloat, color: UIColor) {
        let shadow = NSShadow()
        shadow.shadowColor = UIColor(white: 0, alpha: 0.18)
        shadow.shadowBlurRadius = 3
        shadow.shadowOffset = CGSize(width: 0, height: 2)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .heavy),
            .foregroundColor: color,
            .shadow: shadow,
        ]
        let str = NSAttributedString(string: text, attributes: attrs)
        let size = str.size()
        let origin = CGPoint(x: rect.midX - size.width / 2,
                             y: rect.midY - size.height / 2)
        str.draw(at: origin)
    }
}
