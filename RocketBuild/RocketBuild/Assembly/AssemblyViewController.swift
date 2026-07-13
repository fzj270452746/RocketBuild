//
//  AssemblyViewController.swift
//  RocketBuild
//
//  The build screen. A vertical column of rocket slots on the right, the
//  owned-tile inventory on the left. Players drag tiles onto slots; the rocket
//  preview and a live stats readout update immediately. Launch commits the
//  configuration to the save store and hands it to the coordinator.
//

import UIKit
import SceneKit

final class AssemblyViewController: UIViewController {

    var onLaunch: ((RocketConfiguration) -> Void)?
    var onBack: (() -> Void)?

    private let services: GameServices
    private var configuration: RocketConfiguration

    // UI.
    private let slotStack = UIStackView()
    private let inventoryCollection: UICollectionView
    private let statsLabel = UILabel()
    private let launchButton = UIButton(type: .system)
    private let backButton = UIButton(type: .system)
    private var slotViews: [SlotView] = []

    /// The hand offered this assembly: a random draw of up to 5 tiles from the
    /// player's full deck. Rolled once per visit so the choice feels fresh, per
    /// the design ("每次是从自己的牌组中随机选择5个展示"). Larger decks make the
    /// draw more varied; a deck of 5 or fewer simply shows the whole deck.
    private(set) var inventoryTiles: [TileInstance] = []

    static let handSize = 5

    private func rollHand() {
        let deck = services.store.data.ownedTiles
        inventoryTiles = Array(deck.shuffled().prefix(Self.handSize))
    }

    func catalogDefinition(_ id: String) -> TileDefinition? { services.catalog.definition(id) }

    /// Renders (cached) the mahjong face image for a tile instance, shared by
    /// the inventory cells and the slot targets so both look like real tiles.
    func tileFace(for tile: TileInstance) -> UIImage? {
        guard let def = services.catalog.definition(tile.definitionID) else { return nil }
        return services.materials.tileFaceImage(
            glyph: def.glyph, suit: def.suit, quality: tile.quality,
            cacheKey: def.faceCacheKey + "_\(tile.quality.rawValue)")
    }

    func isInstalled(_ instanceID: UUID) -> Bool {
        configuration.slots.contains(instanceID)
    }

    /// Drops any installed tile that isn't part of the freshly-rolled hand, so
    /// the slot column only ever shows tiles the player can currently see.
    private func pruneInstallsOutsideHand() {
        let handIDs = Set(inventoryTiles.map(\.instanceID))
        for index in configuration.slots.indices {
            if let id = configuration.slots[index], !handIDs.contains(id) {
                configuration.clear(at: index)
            }
        }
    }

    /// Installs a dragged tile (by instance ID) into a slot and refreshes UI.
    func installTile(_ instanceID: UUID, atSlot index: Int) {
        configuration.install(instanceID, at: index)
        refreshSlotContents()
        refreshStats()
        inventoryCollection.reloadData()
        services.audio.play(.coin)
    }

    /// Tap-to-toggle: remove the tile if it is already installed, otherwise put
    /// it in the first empty slot. This is the primary (tap) build interaction;
    /// dragging onto a specific slot still works for deliberate placement.
    func toggleTile(_ instanceID: UUID) {
        if let existing = configuration.slots.firstIndex(of: instanceID) {
            configuration.clear(at: existing)
        } else if let empty = configuration.slots.firstIndex(where: { $0 == nil }) {
            configuration.install(instanceID, at: empty)
        } else {
            // All slots full: replace the last one so tapping still does something.
            configuration.install(instanceID, at: configuration.slotCount - 1)
        }
        refreshSlotContents()
        refreshStats()
        inventoryCollection.reloadData()
        services.audio.play(.coin)
    }

    init(services: GameServices) {
        self.services = services
        self.configuration = services.store.data.configuration
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.itemSize = CGSize(width: 64, height: 86)
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        self.inventoryCollection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Palette.spaceBottom
        // Slot count is driven by the player's level; make sure the loadout
        // matches before we build the slot column.
        configuration.resize(to: services.progression.slotCount)
        // Clear any stale installs referencing tiles that aren't in this hand.
        rollHand()
        pruneInstallsOutsideHand()
        buildLayout()
        buildSlots()
        setupInventoryDragDrop(inventoryCollection)
        refreshStats()
    }

    // MARK: Layout

    private func buildLayout() {
        let gradient = CAGradientLayer()
        gradient.frame = UIScreen.main.bounds
        gradient.colors = [Palette.spaceTop.cgColor, Palette.spaceBottom.cgColor]
        view.layer.insertSublayer(gradient, at: 0)

        // Slot column (right side).
        slotStack.axis = .vertical
        slotStack.alignment = .center
        slotStack.distribution = .equalSpacing
        slotStack.spacing = 10
        slotStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(slotStack)

        // Inventory (bottom).
        inventoryCollection.translatesAutoresizingMaskIntoConstraints = false
        inventoryCollection.backgroundColor = UIColor(white: 0, alpha: 0.2)
        inventoryCollection.layer.cornerRadius = 12
        inventoryCollection.dataSource = self
        inventoryCollection.delegate = self
        inventoryCollection.register(TileCell.self, forCellWithReuseIdentifier: TileCell.reuseID)
        view.addSubview(inventoryCollection)

        // Stats readout.
        statsLabel.translatesAutoresizingMaskIntoConstraints = false
        statsLabel.numberOfLines = 0
        statsLabel.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        statsLabel.textColor = .white
        view.addSubview(statsLabel)

        // Buttons.
        configureButton(launchButton, title: "LAUNCH ▲", color: Palette.hullAccent)
        launchButton.addTarget(self, action: #selector(launchTapped), for: .touchUpInside)
        view.addSubview(launchButton)

        configureButton(backButton, title: "‹ Back", color: Palette.hud)
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        view.addSubview(backButton)

        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            backButton.heightAnchor.constraint(equalToConstant: 40),
            backButton.widthAnchor.constraint(equalToConstant: 88),

            slotStack.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 12),
            slotStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            statsLabel.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 20),
            statsLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            inventoryCollection.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            inventoryCollection.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            inventoryCollection.bottomAnchor.constraint(equalTo: launchButton.topAnchor, constant: -12),
            inventoryCollection.heightAnchor.constraint(equalToConstant: 190),

            launchButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            launchButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            launchButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            launchButton.heightAnchor.constraint(equalToConstant: 56),
        ])
    }

    private func configureButton(_ button: UIButton, title: String, color: UIColor) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .heavy)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = color.withAlphaComponent(0.85)
        button.layer.cornerRadius = 12
    }

    private func buildSlots() {
        slotViews.forEach { $0.removeFromSuperview() }
        slotViews.removeAll()
        for i in 0..<configuration.slotCount {
            let slot = SlotView(index: i)
            slot.translatesAutoresizingMaskIntoConstraints = false
            slot.widthAnchor.constraint(equalToConstant: 58).isActive = true
            slot.heightAnchor.constraint(equalToConstant: 78).isActive = true
            slot.onTap = { [weak self] index in self?.clearSlot(index) }
            // Each slot accepts dropped inventory tiles.
            slot.addInteraction(UIDropInteraction(delegate: self))
            slotStack.addArrangedSubview(slot)
            slotViews.append(slot)
        }
        refreshSlotContents()
    }

    // MARK: State

    func refreshSlotContents() {
        let inv = services.store.inventory
        for slot in slotViews {
            if let id = configuration.slots[slot.index], let inst = inv[id],
               let face = tileFace(for: inst) {
                slot.show(face: face, quality: inst.quality)
            } else {
                slot.showEmpty()
            }
        }
    }

    func refreshStats() {
        let totals = aggregatedStats()
        statsLabel.text = String(format:
            "FUEL   %.0f\nSPEED  %.1f\nSHIELD %.0f\nCTRL   %.1f\nMAGNET %.1f\nWEIGHT %.0f",
            totals.fuel, totals.speed, totals.shield, totals.control,
            totals.magnetRange, totals.weight)
    }

    /// Sums base chassis + installed contributions for the live readout.
    private func aggregatedStats() -> RocketStats {
        var totals = RocketStats.baseChassis
        let inv = services.store.inventory
        for case let id? in configuration.slots {
            if let inst = inv[id], let def = services.catalog.definition(inst.definitionID) {
                totals += def.statContribution.scaledBenefits(by: inst.quality.powerScale)
            }
        }
        return totals
    }

    private func clearSlot(_ index: Int) {
        configuration.clear(at: index)
        refreshSlotContents()
        refreshStats()
        inventoryCollection.reloadData()
    }

    // MARK: Actions

    @objc private func launchTapped() {
        services.store.update { $0.configuration = configuration }
        services.audio.play(.launch)
        onLaunch?(configuration)
    }

    @objc private func backTapped() { onBack?() }
}
