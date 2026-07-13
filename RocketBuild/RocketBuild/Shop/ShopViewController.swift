//
//  ShopViewController.swift
//  RocketBuild
//
//  The coin sink that closes the progression loop: spend coins earned in flight
//  to pull new mahjong tiles (single / ten-pull) that join the player's deck.
//  Higher-rarity tiles boost stats more. Newly drawn tiles are shown as rendered
//  faces so the player sees exactly what they got. Slots are earned by levelling
//  up (not bought here); an info panel shows the player's level and deck size.
//  Services are injected; no globals.
//

import UIKit

final class ShopViewController: UIViewController {

    var onBack: (() -> Void)?

    private let services: GameServices

    // UI.
    private let coinLabel = UILabel()
    private let titleLabel = UILabel()
    private let singleButton = UIButton(type: .system)
    private let tenButton = UIButton(type: .system)
    private let infoLabel = UILabel()
    private let backButton = UIButton(type: .system)
    private let resultsLabel = UILabel()
    private let resultsCollection: UICollectionView

    /// Faces most-recently drawn, newest first, shown in the results grid.
    private var lastPulled: [TileInstance] = []

    init(services: GameServices) {
        self.services = services
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.itemSize = CGSize(width: 64, height: 86)
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        self.resultsCollection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Palette.spaceBottom
        buildBackground()
        buildLayout()
        refresh()
    }

    // MARK: Layout

    private func buildBackground() {
        let gradient = CAGradientLayer()
        gradient.frame = UIScreen.main.bounds
        gradient.colors = [Palette.spaceTop.cgColor, Palette.spaceBottom.cgColor]
        view.layer.insertSublayer(gradient, at: 0)
    }

    private func buildLayout() {
        configureButton(backButton, title: "‹ Back", color: Palette.hud)
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        view.addSubview(backButton)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "TILE SHOP"
        titleLabel.font = .systemFont(ofSize: 26, weight: .heavy)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        view.addSubview(titleLabel)

        coinLabel.translatesAutoresizingMaskIntoConstraints = false
        coinLabel.font = .monospacedSystemFont(ofSize: 18, weight: .bold)
        coinLabel.textColor = Palette.coin
        coinLabel.textAlignment = .center
        view.addSubview(coinLabel)

        configureButton(singleButton, title: "", color: Palette.hullAccent)
        singleButton.addTarget(self, action: #selector(pullSingleTapped), for: .touchUpInside)
        view.addSubview(singleButton)

        configureButton(tenButton, title: "", color: Palette.hullAccent)
        tenButton.addTarget(self, action: #selector(pullTenTapped), for: .touchUpInside)
        view.addSubview(tenButton)

        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        infoLabel.font = .monospacedSystemFont(ofSize: 13, weight: .semibold)
        infoLabel.textColor = UIColor(white: 1, alpha: 0.85)
        infoLabel.textAlignment = .center
        infoLabel.numberOfLines = 0
        infoLabel.backgroundColor = Palette.quality(.purple).withAlphaComponent(0.25)
        infoLabel.layer.cornerRadius = 12
        infoLabel.layer.masksToBounds = true
        view.addSubview(infoLabel)

        resultsLabel.translatesAutoresizingMaskIntoConstraints = false
        resultsLabel.text = "LATEST PULL"
        resultsLabel.font = .monospacedSystemFont(ofSize: 12, weight: .semibold)
        resultsLabel.textColor = UIColor(white: 1, alpha: 0.6)
        view.addSubview(resultsLabel)

        resultsCollection.translatesAutoresizingMaskIntoConstraints = false
        resultsCollection.backgroundColor = UIColor(white: 0, alpha: 0.2)
        resultsCollection.layer.cornerRadius = 12
        resultsCollection.dataSource = self
        resultsCollection.register(TileCell.self, forCellWithReuseIdentifier: TileCell.reuseID)
        view.addSubview(resultsCollection)

        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            backButton.heightAnchor.constraint(equalToConstant: 40),
            backButton.widthAnchor.constraint(equalToConstant: 88),

            titleLabel.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 12),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            coinLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            coinLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            singleButton.topAnchor.constraint(equalTo: coinLabel.bottomAnchor, constant: 24),
            singleButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            singleButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            singleButton.heightAnchor.constraint(equalToConstant: 56),

            tenButton.topAnchor.constraint(equalTo: singleButton.bottomAnchor, constant: 12),
            tenButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            tenButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            tenButton.heightAnchor.constraint(equalToConstant: 56),

            infoLabel.topAnchor.constraint(equalTo: tenButton.bottomAnchor, constant: 16),
            infoLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            infoLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            infoLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 56),

            resultsLabel.topAnchor.constraint(equalTo: infoLabel.bottomAnchor, constant: 20),
            resultsLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            resultsCollection.topAnchor.constraint(equalTo: resultsLabel.bottomAnchor, constant: 8),
            resultsCollection.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            resultsCollection.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            resultsCollection.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
        ])
    }

    private func configureButton(_ button: UIButton, title: String, color: UIColor) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .heavy)
        button.titleLabel?.numberOfLines = 2
        button.titleLabel?.textAlignment = .center
        button.setTitleColor(.white, for: .normal)
        button.setTitleColor(UIColor(white: 1, alpha: 0.35), for: .disabled)
        button.backgroundColor = color.withAlphaComponent(0.85)
        button.layer.cornerRadius = 12
    }

    // MARK: State

    private var progression: Progression { services.progression }

    private func refresh() {
        let coins = services.store.data.coins
        coinLabel.text = "COINS  ◆ \(coins)"

        singleButton.setTitle("PULL ×1   ◆ \(Progression.singlePullCost)", for: .normal)
        singleButton.isEnabled = coins >= Progression.singlePullCost
        singleButton.alpha = singleButton.isEnabled ? 1 : 0.5

        tenButton.setTitle("PULL ×10   ◆ \(Progression.tenPullCost)", for: .normal)
        tenButton.isEnabled = coins >= Progression.tenPullCost
        tenButton.alpha = tenButton.isEnabled ? 1 : 0.5

        let deckSize = services.store.data.ownedTiles.count
        let levelLine = progression.isMaxLevel
            ? "LV \(progression.level) (MAX)"
            : "LV \(progression.level)   XP \(progression.xp)/\(progression.xpToNext)"
        infoLabel.text = "\(levelLine)\nSLOTS \(progression.slotCount)   DECK \(deckSize) tiles\nFly higher to level up and unlock slots"
    }

    private func tileFace(for tile: TileInstance) -> UIImage? {
        guard let def = services.catalog.definition(tile.definitionID) else { return nil }
        return services.materials.tileFaceImage(
            glyph: def.glyph, suit: def.suit, quality: tile.quality,
            cacheKey: def.faceCacheKey + "_\(tile.quality.rawValue)")
    }

    // MARK: Actions

    @objc private func pullSingleTapped() {
        guard let tile = progression.pullOne(from: services.catalog) else { return }
        lastPulled = [tile]
        services.audio.play(.coin)
        resultsCollection.reloadData()
        refresh()
    }

    @objc private func pullTenTapped() {
        let tiles = progression.pullTen(from: services.catalog)
        guard !tiles.isEmpty else { return }
        lastPulled = tiles
        services.audio.play(.magnet)
        resultsCollection.reloadData()
        refresh()
    }

    @objc private func backTapped() { onBack?() }
}

// MARK: - Results grid

extension ShopViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        lastPulled.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TileCell.reuseID,
                                                     for: indexPath) as! TileCell
        let tile = lastPulled[indexPath.item]
        if let face = tileFace(for: tile) {
            cell.configure(face: face, installed: false)
        }
        return cell
    }
}
