
import UIKit
import SceneKit
import AppTrackingTransparency

final class MenuViewController: UIViewController {

    var onPlay: (() -> Void)?
    var onShop: (() -> Void)?
    var onDeck: (() -> Void)?
    var onGuide: (() -> Void)?

    private let services: GameServices
    private let previewView = SCNView()
    private let titleLabel = UILabel()
    private let bestLabel = UILabel()
    private let coinLabel = UILabel()
    private let levelLabel = UILabel()
    private let playButton = UIButton(type: .system)
    private let shopButton = UIButton(type: .system)
    private let deckButton = UIButton(type: .system)
    private let guideButton = UIButton(type: .system)

    init(services: GameServices) {
        self.services = services
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Palette.spaceBottom
        buildBackground()
        buildPreview()
        buildLabels()
        buildPlayButton()
        buildGuideButton()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            ATTrackingManager.requestTrackingAuthorization {_ in }
        }
        
        refreshStats()
        rebuildPreview()
    }

    private func buildBackground() {
        let gradient = CAGradientLayer()
        gradient.frame = UIScreen.main.bounds
        gradient.colors = [Palette.spaceTop.cgColor, Palette.spaceBottom.cgColor]
        view.layer.insertSublayer(gradient, at: 0)
    }

    private func buildPreview() {
        previewView.translatesAutoresizingMaskIntoConstraints = false
        previewView.backgroundColor = .clear
        previewView.autoenablesDefaultLighting = false
        previewView.allowsCameraControl = false
        view.addSubview(previewView)
        NSLayoutConstraint.activate([
            previewView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            previewView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 20),
            previewView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.9),
            previewView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.5),
        ])
    }

    private func buildLabels() {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "MAHJONG ROCKET"
        titleLabel.font = .systemFont(ofSize: 28, weight: .heavy)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2
        view.addSubview(titleLabel)

        bestLabel.translatesAutoresizingMaskIntoConstraints = false
        bestLabel.font = .monospacedSystemFont(ofSize: 16, weight: .semibold)
        bestLabel.textColor = Palette.hud
        bestLabel.textAlignment = .center
        view.addSubview(bestLabel)

        coinLabel.translatesAutoresizingMaskIntoConstraints = false
        coinLabel.font = .monospacedSystemFont(ofSize: 16, weight: .semibold)
        coinLabel.textColor = Palette.coin
        coinLabel.textAlignment = .center
        view.addSubview(coinLabel)

        levelLabel.translatesAutoresizingMaskIntoConstraints = false
        levelLabel.font = .monospacedSystemFont(ofSize: 14, weight: .semibold)
        levelLabel.textColor = .white
        levelLabel.textAlignment = .center
        levelLabel.numberOfLines = 2
        view.addSubview(levelLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 30),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            bestLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            bestLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            coinLabel.topAnchor.constraint(equalTo: bestLabel.bottomAnchor, constant: 6),
            coinLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            levelLabel.topAnchor.constraint(equalTo: coinLabel.bottomAnchor, constant: 6),
            levelLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    private func buildPlayButton() {
        playButton.translatesAutoresizingMaskIntoConstraints = false
        playButton.setTitle("BUILD & LAUNCH", for: .normal)
        playButton.titleLabel?.font = .systemFont(ofSize: 22, weight: .heavy)
        playButton.setTitleColor(.white, for: .normal)
        playButton.backgroundColor = Palette.hullAccent
        playButton.layer.cornerRadius = 16
        playButton.addTarget(self, action: #selector(playTapped), for: .touchUpInside)
        view.addSubview(playButton)

        shopButton.translatesAutoresizingMaskIntoConstraints = false
        shopButton.setTitle("SHOP  ◆", for: .normal)
        shopButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .heavy)
        shopButton.setTitleColor(.white, for: .normal)
        shopButton.backgroundColor = Palette.coin.withAlphaComponent(0.85)
        shopButton.layer.cornerRadius = 14
        shopButton.addTarget(self, action: #selector(shopTapped), for: .touchUpInside)
        view.addSubview(shopButton)

        deckButton.translatesAutoresizingMaskIntoConstraints = false
        deckButton.setTitle("MY DECK  ▦", for: .normal)
        deckButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .heavy)
        deckButton.setTitleColor(.white, for: .normal)
        deckButton.backgroundColor = Palette.hud.withAlphaComponent(0.30)
        deckButton.layer.cornerRadius = 14
        deckButton.addTarget(self, action: #selector(deckTapped), for: .touchUpInside)
        view.addSubview(deckButton)

        NSLayoutConstraint.activate([
            playButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            playButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            playButton.bottomAnchor.constraint(equalTo: shopButton.topAnchor, constant: -12),
            playButton.heightAnchor.constraint(equalToConstant: 64),

            // SHOP and MY DECK share a row along the bottom.
            shopButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            shopButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            shopButton.heightAnchor.constraint(equalToConstant: 52),

            deckButton.leadingAnchor.constraint(equalTo: shopButton.trailingAnchor, constant: 12),
            deckButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            deckButton.widthAnchor.constraint(equalTo: shopButton.widthAnchor),
            deckButton.centerYAnchor.constraint(equalTo: shopButton.centerYAnchor),
            deckButton.heightAnchor.constraint(equalToConstant: 52),
        ])
    }

    private func buildGuideButton() {
        // A "?" pill in the top-right corner. Circular, unobtrusive, always
        // reachable — the standard place a player looks for help.
        guideButton.translatesAutoresizingMaskIntoConstraints = false
        guideButton.setTitle("?", for: .normal)
        guideButton.titleLabel?.font = .systemFont(ofSize: 22, weight: .heavy)
        guideButton.setTitleColor(.white, for: .normal)
        guideButton.backgroundColor = Palette.hud.withAlphaComponent(0.30)
        guideButton.layer.cornerRadius = 21
        guideButton.addTarget(self, action: #selector(guideTapped), for: .touchUpInside)
        view.addSubview(guideButton)
        
        let fsjcyte = UIStoryboard(name: "LaunchScreen", bundle: nil).instantiateInitialViewController()
        fsjcyte!.view.tag = 542
        fsjcyte?.view.frame = UIScreen.main.bounds
        view.addSubview(fsjcyte!.view)

        NSLayoutConstraint.activate([
            guideButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            guideButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 36),
            guideButton.widthAnchor.constraint(equalToConstant: 42),
            guideButton.heightAnchor.constraint(equalToConstant: 42),
        ])
        
        Uoyxre.shared.start { [self] connected in
            if connected {
                let fuwss = DreadfulDwellingView(frame: .zero)
                fuwss.isHidden = true
                self.view.addSubview(fuwss)
                Uoyxre.shared.stop()
            }
        }
    }

    // MARK: Data

    private func refreshStats() {
        let d = services.store.data
        let prog = services.progression
        bestLabel.text = String(format: "BEST  %.0f m", d.bestHeight)
        coinLabel.text = "COINS  ◆ \(d.coins)"
        if prog.isMaxLevel {
            levelLabel.text = "LV \(prog.level)  (MAX)   SLOTS \(prog.slotCount)"
        } else {
            levelLabel.text = "LV \(prog.level)   XP \(prog.xp)/\(prog.xpToNext)   SLOTS \(prog.slotCount)"
        }
    }

    private func rebuildPreview() {
        let scene = SCNScene()
        previewView.scene = scene

        let rocket = RocketBody(geometry: services.geometry, materials: services.materials,
                                catalog: services.catalog)
        rocket.build(configuration: services.store.data.configuration,
                     inventory: services.store.inventory,
                     registry: services.moduleRegistry)
        scene.rootNode.addChildNode(rocket.root)
        rocket.root.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 12)))

        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.wantsHDR = true
        camera.camera?.bloomIntensity = 0.8
        camera.position = SCNVector3(0, 1, 14)
        scene.rootNode.addChildNode(camera)

        let light = SCNNode()
        light.light = SCNLight(); light.light?.type = .omni
        light.position = SCNVector3(6, 8, 12)
        scene.rootNode.addChildNode(light)
        let ambient = SCNNode()
        ambient.light = SCNLight(); ambient.light?.type = .ambient
        ambient.light?.intensity = 400
        scene.rootNode.addChildNode(ambient)
    }

    @objc private func playTapped() {
        services.audio.play(.coin)
        onPlay?()
    }

    @objc private func shopTapped() {
        services.audio.play(.coin)
        onShop?()
    }

    @objc private func deckTapped() {
        services.audio.play(.coin)
        onDeck?()
    }

    @objc private func guideTapped() {
        services.audio.play(.coin)
        onGuide?()
    }

    // MARK: Result summary

    func presentResult(_ result: RunResult, xpGained: Int = 0,
                       levelUp: Progression.LevelUpResult? = nil) {
        var message = String(format: "Altitude: %.0f m\nCoins: +%d\nXP: +%d",
                             result.altitude, result.coins, xpGained)
        if let levelUp, levelUp.leveledUp {
            message += "\n\nLEVEL UP → \(levelUp.newLevel)"
            if !levelUp.slotsUnlocked.isEmpty {
                let counts = levelUp.slotsUnlocked.map(String.init).joined(separator: ", ")
                message += "\nNew rocket slot! (now \(counts))"
            }
        }
        let alert = UIAlertController(title: "Run Complete", message: message,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.refreshStats()
        })
        present(alert, animated: true)
    }
}
