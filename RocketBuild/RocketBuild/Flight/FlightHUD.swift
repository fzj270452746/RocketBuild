//
//  FlightHUD.swift
//  RocketBuild
//
//  SpriteKit overlay drawn on top of the SceneKit view. Shows altitude, coins,
//  fuel and shield at the top and hosts the boost / pause controls. Pure view
//  layer — it reads a snapshot struct and never touches gameplay systems.
//

import SpriteKit

/// Immutable snapshot the flight loop hands to the HUD each frame.
struct HUDSnapshot {
    var altitude: Double
    var coins: Int
    var fuelFraction: Double
    var shieldFraction: Double
    var multiplier: Int
    var eventName: String?
}

final class FlightHUD: SKScene {

    private let altitudeLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let coinLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let multiplierLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let eventLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let fuelBar = BarNode(color: Palette.warning, width: 140)
    private let shieldBar = BarNode(color: Palette.hud, width: 140)

    /// Insets from the owning view's safe area. Set by the flight VC so the HUD
    /// never draws under the notch/status bar or behind the pause button.
    var safeInsets: UIEdgeInsets = .zero {
        didSet { layout() }
    }

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        scaleMode = .resizeFill
        buildLabels()
    }

    private func buildLabels() {
        altitudeLabel.fontSize = 22
        altitudeLabel.fontColor = .white
        altitudeLabel.horizontalAlignmentMode = .left
        addChild(altitudeLabel)

        coinLabel.fontSize = 18
        coinLabel.fontColor = Palette.coin
        coinLabel.horizontalAlignmentMode = .left
        addChild(coinLabel)

        multiplierLabel.fontSize = 20
        multiplierLabel.fontColor = Palette.good
        multiplierLabel.horizontalAlignmentMode = .right
        addChild(multiplierLabel)

        eventLabel.fontSize = 20
        eventLabel.fontColor = Palette.warning
        eventLabel.horizontalAlignmentMode = .center
        eventLabel.alpha = 0
        addChild(eventLabel)

        addChild(fuelBar)
        addChild(shieldBar)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        layout()
    }

    private func layout() {
        guard size.width > 0, size.height > 0 else { return }
        // SpriteKit's origin is bottom-left, so "top" counts down from the height.
        let left = safeInsets.left + 20
        let right = size.width - safeInsets.right - 20
        let top = size.height - safeInsets.top - 24
        // Top-left: altitude then coins. The pause button now lives top-right, so
        // this corner is clear.
        altitudeLabel.position = CGPoint(x: left, y: top)
        coinLabel.position = CGPoint(x: left, y: top - 26)
        // Top-right, but pushed below the 44pt pause button so they don't overlap.
        let barTop = top - 52
        fuelBar.position = CGPoint(x: right - 140, y: barTop)
        shieldBar.position = CGPoint(x: right - 140, y: barTop - 20)
        multiplierLabel.position = CGPoint(x: right, y: barTop - 44)
        eventLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.7)
    }

    func apply(_ s: HUDSnapshot) {
        altitudeLabel.text = String(format: "%.0f m", s.altitude)
        coinLabel.text = "◆ \(s.coins)"
        multiplierLabel.text = s.multiplier > 1 ? "x\(s.multiplier)" : ""
        fuelBar.setFraction(CGFloat(s.fuelFraction))
        shieldBar.setFraction(CGFloat(s.shieldFraction))

        if let name = s.eventName, eventLabel.userData?["name"] as? String != name {
            eventLabel.text = name
            eventLabel.userData = ["name": name]
            eventLabel.removeAllActions()
            eventLabel.run(.sequence([.fadeIn(withDuration: 0.3),
                                      .wait(forDuration: 2.0),
                                      .fadeOut(withDuration: 0.6)]))
        }
    }
}

/// A simple two-layer progress bar.
final class BarNode: SKNode {
    private let background: SKSpriteNode
    private let fill: SKSpriteNode
    private let barWidth: CGFloat

    init(color: UIColor, width: CGFloat) {
        barWidth = width
        background = SKSpriteNode(color: UIColor(white: 1, alpha: 0.18),
                                  size: CGSize(width: width, height: 10))
        fill = SKSpriteNode(color: color, size: CGSize(width: width, height: 10))
        super.init()
        background.anchorPoint = CGPoint(x: 0, y: 0.5)
        fill.anchorPoint = CGPoint(x: 0, y: 0.5)
        addChild(background)
        addChild(fill)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setFraction(_ f: CGFloat) {
        let clamped = max(0, min(1, f))
        fill.xScale = max(0.001, clamped)
    }
}
