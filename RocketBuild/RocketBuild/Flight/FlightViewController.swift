//
//  FlightViewController.swift
//  RocketBuild
//
//  Hosts the SceneKit flight experience. Builds the layered scene graph
//  (WorldRoot / RocketRoot / HazardLayer / PickupLayer / CameraRig /
//  Environment), drives a fixed game loop from the render callback, translates
//  swipes into lateral movement, resolves physics contacts and streams the
//  endless world. Owns its FlightContext — there is no global game manager.
//

import UIKit
import SceneKit
import SpriteKit

protocol FlightViewControllerDelegate: AnyObject {
    func flightDidEnd(result: RunResult)
}

/// Summary handed back to the coordinator when a run finishes.
struct RunResult {
    var altitude: Double
    var coins: Int
    var score: Int
}

final class FlightViewController: UIViewController {

    // Injected dependencies.
    let services: GameServices
    private let configuration: RocketConfiguration
    private let inventory: [UUID: TileInstance]
    weak var delegate: FlightViewControllerDelegate?

    // Scene infrastructure.
    let scnView = SCNView()
    let scene = SCNScene()
    lazy var hud = FlightHUD(size: view.bounds.size)

    // Layered roots (design §16 hierarchy).
    let worldRoot = SCNNode()
    let rocketRoot = SCNNode()
    let hazardLayer = SCNNode()
    let pickupLayer = SCNNode()

    // Systems.
    let rocket: RocketBody
    let context: FlightContext
    let cameraRig = CameraRig()
    let environment: Environment
    let spawner: Spawner
    let events = EventDirector()

    // Loop state.
    var lastTime: TimeInterval = 0
    var launchCountdownRemaining: Double = 3
    var hasLaunched = false
    var isPaused = false
    var isFinished = false

    // Streaming bookkeeping.
    var nextHazardHeight: Float = 8
    var nextPickupHeight: Float = 6
    var liveHazards: [Entity] = []
    var livePickups: [Entity] = []
    var pendingContacts: [SCNPhysicsContact] = []

    // Input.
    var targetLateral: Float = 0
    var panBase: Float = 0
    var boostHeld = false

    // Controls.
    private let boostButton = UIButton(type: .system)
    private let pauseButton = UIButton(type: .system)
    // Only visible while paused; lets the player abandon the run and go back.
    private let quitButton = UIButton(type: .system)

    init(services: GameServices, configuration: RocketConfiguration,
         inventory: [UUID: TileInstance]) {
        self.services = services
        self.configuration = configuration
        self.inventory = inventory
        self.rocket = RocketBody(geometry: services.geometry,
                                 materials: services.materials,
                                 catalog: services.catalog)
        self.rocket.build(configuration: configuration, inventory: inventory,
                          registry: services.moduleRegistry)
        self.context = FlightContext(rocket: rocket)
        self.environment = Environment(geometry: services.geometry, materials: services.materials)
        self.spawner = Spawner(geometry: services.geometry, materials: services.materials)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupScene()
        setupControls()
        setupContextHooks()
        wireEvents()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        scnView.frame = view.bounds
        hud.size = view.bounds.size
        hud.safeInsets = view.safeAreaInsets
    }

    // MARK: Setup

    private func setupScene() {
        scnView.frame = view.bounds
        scnView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scnView.scene = scene
        scnView.antialiasingMode = .multisampling2X
        scnView.rendersContinuously = true
        scnView.delegate = self
        scnView.overlaySKScene = hud
        scnView.preferredFramesPerSecond = 60
        view.addSubview(scnView)

        // The world scrolls downward while the rocket and camera stay fixed near
        // the origin. Only the scrolling content (environment, hazards, pickups)
        // lives under worldRoot; the rocket rig and camera are parented directly
        // to the scene so they never sink with the world. Hazard/pickup heights
        // therefore read directly against `worldScroll` (see +World).
        scene.rootNode.addChildNode(worldRoot)
        worldRoot.addChildNode(environment.root)
        worldRoot.addChildNode(hazardLayer)
        worldRoot.addChildNode(pickupLayer)

        rocketRoot.addChildNode(rocket.root)
        rocketRoot.position = SCNVector3(0, 0, 0)
        scene.rootNode.addChildNode(rocketRoot)

        scene.rootNode.addChildNode(cameraRig.node)
        scnView.pointOfView = cameraRig.node

        environment.applyBackground(to: scene, size: view.bounds.size)

        // Rocket physics body for contact detection.
        let shape = SCNPhysicsShape(geometry: SCNCapsule(capRadius: 0.6, height: 4), options: nil)
        let body = SCNPhysicsBody(type: .kinematic, shape: shape)
        body.categoryBitMask = PhysicsCategory.rocket
        body.contactTestBitMask = PhysicsCategory.hazard | PhysicsCategory.pickup
        body.collisionBitMask = 0
        rocket.root.physicsBody = body
        rocket.root.name = "rocket"

        scene.physicsWorld.contactDelegate = self

        // Star trail behind the rocket.
        let trail = services.particles.starTrail()
        let trailNode = SCNNode()
        trailNode.position = SCNVector3(0, -2.5, 0)
        trailNode.addParticleSystem(trail)
        rocket.root.addChildNode(trailNode)
    }

    private func setupControls() {
        // Swipe/drag anywhere to steer.
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        scnView.addGestureRecognizer(pan)

        configureControlButton(boostButton, title: "BOOST", color: Palette.warning)
        boostButton.addTarget(self, action: #selector(boostDown), for: .touchDown)
        boostButton.addTarget(self, action: #selector(boostUp),
                              for: [.touchUpInside, .touchUpOutside, .touchCancel])
        view.addSubview(boostButton)

        configureControlButton(pauseButton, title: "II", color: Palette.hud)
        pauseButton.addTarget(self, action: #selector(togglePause), for: .touchUpInside)
        view.addSubview(pauseButton)

        configureControlButton(quitButton, title: "QUIT", color: Palette.warning)
        quitButton.addTarget(self, action: #selector(quitTapped), for: .touchUpInside)
        quitButton.isHidden = true
        view.addSubview(quitButton)

        NSLayoutConstraint.activate([
            boostButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            boostButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            boostButton.widthAnchor.constraint(equalToConstant: 96),
            boostButton.heightAnchor.constraint(equalToConstant: 96),

            pauseButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            pauseButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            pauseButton.widthAnchor.constraint(equalToConstant: 44),
            pauseButton.heightAnchor.constraint(equalToConstant: 44),

            quitButton.trailingAnchor.constraint(equalTo: pauseButton.trailingAnchor),
            quitButton.topAnchor.constraint(equalTo: pauseButton.bottomAnchor, constant: 12),
            quitButton.widthAnchor.constraint(equalToConstant: 72),
            quitButton.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    private func configureControlButton(_ button: UIButton, title: String, color: UIColor) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .heavy)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = color.withAlphaComponent(0.35)
        button.layer.cornerRadius = title == "BOOST" ? 48 : 22
        button.layer.borderWidth = 2
        button.layer.borderColor = color.cgColor
    }

    private func setupContextHooks() {
        context.onEffect = { [weak self] effect in self?.handleEffect(effect) }
        context.onDetonate = { [weak self] radius in self?.detonate(radius: radius) }
    }

    private func wireEvents() {
        events.onEventBegan = { [weak self] event in
            self?.currentEventName = event.name
        }
        events.onEventEnded = { [weak self] in
            self?.currentEventName = nil
        }
    }

    var currentEventName: String?

    // MARK: Input

    @objc private func handlePan(_ gr: UIPanGestureRecognizer) {
        switch gr.state {
        case .began:
            panBase = rocket.root.position.x
        case .changed, .ended:
            let translation = gr.translation(in: scnView)
            // Map horizontal drag onto a target lateral offset, clamped to the
            // play width. Absolute base means the rocket does not snap back.
            targetLateral = MathUtil.clampf(panBase + Float(translation.x) / 45, -6, 6)
        default:
            break
        }
    }

    @objc private func boostDown() { boostHeld = true; activateModules() }
    @objc private func boostUp() { boostHeld = false }

    @objc private func togglePause() {
        isPaused.toggle()
        scnView.scene?.isPaused = isPaused
        pauseButton.setTitle(isPaused ? "▶" : "II", for: .normal)
        // The quit option is only offered while the run is paused.
        quitButton.isHidden = !isPaused
    }

    @objc private func quitTapped() {
        // Confirm before abandoning the run so a stray tap can't end it.
        let alert = UIAlertController(title: "Quit Game",
                                      message: "End this flight and return to the menu?",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Quit", style: .destructive) { [weak self] _ in
            self?.quitToMenu()
        })
        present(alert, animated: true)
    }

    /// Abandon the current run, banking whatever progress was made, and hand
    /// control back to the coordinator (which pops to the menu).
    private func quitToMenu() {
        guard !isFinished else { return }
        isFinished = true
        scnView.scene?.isPaused = false
        let result = RunResult(altitude: context.altitude,
                               coins: context.coins,
                               score: context.altitude > 0 ? Int(context.altitude) : 0)
        delegate?.flightDidEnd(result: result)
    }

    /// Boost also fires any activatable modules (shield, explosion, speed).
    private func activateModules() {
        for module in rocket.modules { module.activate(context: context) }
    }
}
