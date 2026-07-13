//
//  DeckViewController.swift
//  RocketBuild
//
//  The player's library viewer. Shows every owned tile instance in the deck as
//  a grid of mahjong faces with name, quality and the stat bonus it grants.
//  Read-only: this is where the player inspects what the shop's gacha has added
//  to their collection. Each assembly still draws a random hand of 5 from here.
//

import UIKit

final class DeckViewController: UIViewController {

    var onBack: (() -> Void)?

    private let services: GameServices
    private let titleLabel = UILabel()
    private let summaryLabel = UILabel()
    private let backButton = UIButton(type: .system)
    private var collection: UICollectionView!

    /// The full deck, sorted so honors lead and numbered suits run in pip order,
    /// with higher qualities first within a definition — stable and easy to scan.
    private var tiles: [TileInstance] = []

    init(services: GameServices) {
        self.services = services
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Palette.spaceBottom
        buildBackground()
        buildHeader()
        buildCollection()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload()
    }

    private func buildBackground() {
        let gradient = CAGradientLayer()
        gradient.frame = UIScreen.main.bounds
        gradient.colors = [Palette.spaceTop.cgColor, Palette.spaceBottom.cgColor]
        view.layer.insertSublayer(gradient, at: 0)
    }

    private func buildHeader() {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "MY DECK"
        titleLabel.font = .systemFont(ofSize: 26, weight: .heavy)
        titleLabel.textColor = .white
        view.addSubview(titleLabel)

        summaryLabel.translatesAutoresizingMaskIntoConstraints = false
        summaryLabel.font = .monospacedSystemFont(ofSize: 13, weight: .semibold)
        summaryLabel.textColor = Palette.hud
        summaryLabel.numberOfLines = 2
        view.addSubview(summaryLabel)

        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.setTitle("✕", for: .normal)
        backButton.titleLabel?.font = .systemFont(ofSize: 22, weight: .bold)
        backButton.setTitleColor(.white, for: .normal)
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        view.addSubview(backButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            backButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            backButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            backButton.widthAnchor.constraint(equalToConstant: 40),
            backButton.heightAnchor.constraint(equalToConstant: 40),

            summaryLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            summaryLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            summaryLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])
    }

    private func buildCollection() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.itemSize = CGSize(width: 104, height: 148)
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing = 16
        layout.sectionInset = UIEdgeInsets(top: 8, left: 16, bottom: 24, right: 16)

        collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collection.translatesAutoresizingMaskIntoConstraints = false
        collection.backgroundColor = .clear
        collection.alwaysBounceVertical = true
        collection.dataSource = self
        collection.register(DeckTileCell.self, forCellWithReuseIdentifier: DeckTileCell.reuseID)
        view.addSubview(collection)

        NSLayoutConstraint.activate([
            collection.topAnchor.constraint(equalTo: summaryLabel.bottomAnchor, constant: 12),
            collection.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collection.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collection.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
    }

    // MARK: Data

    private func reload() {
        let owned = services.store.data.ownedTiles
        tiles = owned.sorted { lhs, rhs in
            let l = services.catalog.definition(lhs.definitionID)
            let r = services.catalog.definition(rhs.definitionID)
            let lKey = sortKey(l), rKey = sortKey(r)
            if lKey != rKey { return lKey < rKey }
            // Same definition: higher quality first.
            return lhs.quality.powerScale > rhs.quality.powerScale
        }

        // Quality breakdown, e.g. "12 tiles · common 8  blue 3  gold 1".
        var counts: [TileQuality: Int] = [:]
        for t in owned { counts[t.quality, default: 0] += 1 }
        let order: [TileQuality] = [.common, .blue, .purple, .gold]
        let breakdown = order.compactMap { q -> String? in
            guard let c = counts[q], c > 0 else { return nil }
            return "\(q.rawValue) \(c)"
        }.joined(separator: "  ")
        summaryLabel.text = "\(owned.count) tiles" + (breakdown.isEmpty ? "" : "\n\(breakdown)")

        collection?.reloadData()
    }

    /// Sort so honors come first, then 萬/條/筒 in pip order.
    private func sortKey(_ def: TileDefinition?) -> String {
        guard let def else { return "z" }
        let suitRank: Int
        switch def.suit {
        case .honor: suitRank = 0
        case .character: suitRank = 1
        case .bamboo: suitRank = 2
        case .dot: suitRank = 3
        }
        return "\(suitRank)_\(def.id)"
    }

    @objc private func backTapped() {
        services.audio.play(.coin)
        onBack?()
    }
}

// MARK: - Data source

extension DeckViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        tiles.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: DeckTileCell.reuseID, for: indexPath) as! DeckTileCell
        let tile = tiles[indexPath.item]
        guard let def = services.catalog.definition(tile.definitionID) else { return cell }
        let face = services.materials.tileFaceImage(
            glyph: def.glyph, suit: def.suit, quality: tile.quality,
            cacheKey: def.faceCacheKey + "_\(tile.quality.rawValue)")
        cell.configure(face: face, name: def.displayName, quality: tile.quality,
                       bonus: Self.bonusText(for: def, quality: tile.quality))
        return cell
    }

    /// A short one-line summary of the tile's main stat bonus, scaled by quality
    /// so higher-tier tiles visibly read as stronger.
    static func bonusText(for def: TileDefinition, quality: TileQuality) -> String {
        let s = def.statContribution.scaledBenefits(by: quality.powerScale)
        var parts: [String] = []
        if s.fuel > 0.05 { parts.append(String(format: "+%.0f fuel", s.fuel)) }
        if s.speed > 0.05 { parts.append(String(format: "+%.1f thrust", s.speed)) }
        if s.control > 0.05 { parts.append(String(format: "+%.1f ctrl", s.control)) }
        if s.shield > 0.05 { parts.append(String(format: "+%.0f shield", s.shield)) }
        if s.magnetRange > 0.05 { parts.append(String(format: "+%.0f magnet", s.magnetRange)) }
        if parts.isEmpty { parts.append(def.ability.kind.rawValue) }
        return parts.prefix(2).joined(separator: " ")
    }
}

// MARK: - Cell

final class DeckTileCell: UICollectionViewCell {
    static let reuseID = "DeckTileCell"

    private let faceView = UIImageView()
    private let nameLabel = UILabel()
    private let bonusLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .clear

        faceView.translatesAutoresizingMaskIntoConstraints = false
        faceView.contentMode = .scaleAspectFit
        faceView.layer.shadowColor = UIColor.black.cgColor
        faceView.layer.shadowOpacity = 0.35
        faceView.layer.shadowRadius = 4
        faceView.layer.shadowOffset = CGSize(width: 0, height: 2)
        contentView.addSubview(faceView)

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        nameLabel.textAlignment = .center
        nameLabel.textColor = .white
        nameLabel.numberOfLines = 1
        nameLabel.adjustsFontSizeToFitWidth = true
        nameLabel.minimumScaleFactor = 0.8
        contentView.addSubview(nameLabel)

        bonusLabel.translatesAutoresizingMaskIntoConstraints = false
        bonusLabel.font = .monospacedSystemFont(ofSize: 9.5, weight: .medium)
        bonusLabel.textAlignment = .center
        bonusLabel.textColor = Palette.hud
        bonusLabel.numberOfLines = 1
        bonusLabel.adjustsFontSizeToFitWidth = true
        bonusLabel.minimumScaleFactor = 0.7
        contentView.addSubview(bonusLabel)

        NSLayoutConstraint.activate([
            faceView.topAnchor.constraint(equalTo: contentView.topAnchor),
            faceView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            faceView.widthAnchor.constraint(equalToConstant: 76),
            faceView.heightAnchor.constraint(equalToConstant: 100),

            nameLabel.topAnchor.constraint(equalTo: faceView.bottomAnchor, constant: 4),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            bonusLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            bonusLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            bonusLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(face: UIImage?, name: String, quality: TileQuality, bonus: String) {
        faceView.image = face
        nameLabel.text = name
        bonusLabel.text = bonus
        // Tint the name by quality so the collection reads at a glance.
        nameLabel.textColor = quality == .common ? .white : Palette.quality(quality)
    }
}
