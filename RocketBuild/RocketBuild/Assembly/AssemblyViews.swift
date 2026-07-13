//
//  AssemblyViews.swift
//  RocketBuild
//
//  View pieces for the assembly screen: a rocket slot target and an inventory
//  tile cell, plus the collection-view data source and drag-and-drop wiring
//  that installs tiles by dragging them onto slots.
//

import UIKit

// MARK: - Slot view

/// A single rocket slot the player drops tiles onto. Tapping a filled slot
/// clears it.
final class SlotView: UIView {
    let index: Int
    var onTap: ((Int) -> Void)?
    private let faceView = UIImageView()
    private let emptyLabel = UILabel()

    init(index: Int) {
        self.index = index
        super.init(frame: .zero)
        layer.cornerRadius = 10
        layer.borderWidth = 2
        layer.borderColor = UIColor(white: 1, alpha: 0.4).cgColor
        backgroundColor = UIColor(white: 1, alpha: 0.08)

        // Auto Layout the children: the slot itself is sized by external
        // constraints (58×78) that resolve *after* init, so an autoresizing
        // mask seeded from the initial zero bounds would leave these at 0×0
        // (the tile face and the "＋" placeholder would never appear).
        faceView.translatesAutoresizingMaskIntoConstraints = false
        faceView.contentMode = .scaleAspectFit
        faceView.isHidden = true
        addSubview(faceView)

        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.textAlignment = .center
        emptyLabel.font = .systemFont(ofSize: 24, weight: .bold)
        addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            faceView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            faceView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            faceView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            faceView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),

            emptyLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func tapped() { onTap?(index) }

    /// Shows a rendered mahjong tile face inside the slot.
    func show(face: UIImage, quality: TileQuality) {
        faceView.image = face
        faceView.isHidden = false
        emptyLabel.isHidden = true
        backgroundColor = UIColor(white: 1, alpha: 0.12)
        layer.borderColor = Palette.quality(quality).cgColor
    }

    func showEmpty() {
        faceView.isHidden = true
        faceView.image = nil
        emptyLabel.isHidden = false
        emptyLabel.text = "＋"
        emptyLabel.textColor = UIColor(white: 1, alpha: 0.5)
        backgroundColor = UIColor(white: 1, alpha: 0.08)
        layer.borderColor = UIColor(white: 1, alpha: 0.4).cgColor
    }

    /// Highlight while a drag hovers over this slot.
    func setHighlighted(_ on: Bool) {
        layer.borderColor = (on ? Palette.good : UIColor(white: 1, alpha: 0.4)).cgColor
        transform = on ? CGAffineTransform(scaleX: 1.1, y: 1.1) : .identity
    }
}

// MARK: - Inventory cell

final class TileCell: UICollectionViewCell {
    static let reuseID = "TileCell"
    private let faceView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .clear

        faceView.frame = contentView.bounds
        faceView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        faceView.contentMode = .scaleAspectFit
        // Soft drop shadow so tiles feel like physical pieces.
        faceView.layer.shadowColor = UIColor.black.cgColor
        faceView.layer.shadowOpacity = 0.35
        faceView.layer.shadowRadius = 4
        faceView.layer.shadowOffset = CGSize(width: 0, height: 2)
        contentView.addSubview(faceView)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(face: UIImage, installed: Bool) {
        faceView.image = face
        contentView.alpha = installed ? 0.3 : 1.0
    }
}

// MARK: - Data source & drag/drop

extension AssemblyViewController: UICollectionViewDataSource, UICollectionViewDelegate,
                                  UICollectionViewDragDelegate {

    func setupInventoryDragDrop(_ collection: UICollectionView) {
        collection.dragDelegate = self
        collection.dragInteractionEnabled = true
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        inventoryTiles.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TileCell.reuseID,
                                                      for: indexPath) as! TileCell
        let tile = inventoryTiles[indexPath.item]
        if let face = tileFace(for: tile) {
            cell.configure(face: face, installed: isInstalled(tile.instanceID))
        }
        return cell
    }

    /// Tapping a tile is the primary way to build: an installed tile is removed,
    /// otherwise it drops into the first empty slot (dragging still works too).
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let tile = inventoryTiles[indexPath.item]
        toggleTile(tile.instanceID)
        collectionView.deselectItem(at: indexPath, animated: false)
    }

    func collectionView(_ collectionView: UICollectionView,
                        itemsForBeginning session: UIDragSession,
                        at indexPath: IndexPath) -> [UIDragItem] {
        let tile = inventoryTiles[indexPath.item]
        let provider = NSItemProvider(object: tile.instanceID.uuidString as NSString)
        let item = UIDragItem(itemProvider: provider)
        item.localObject = tile.instanceID
        return [item]
    }
}

// MARK: - Slot drop handling

extension AssemblyViewController: UIDropInteractionDelegate {

    func dropInteraction(_ interaction: UIDropInteraction,
                        canHandle session: UIDropSession) -> Bool {
        session.localDragSession != nil
    }

    func dropInteraction(_ interaction: UIDropInteraction,
                        sessionDidUpdate session: UIDropSession) -> UIDropProposal {
        (interaction.view as? SlotView)?.setHighlighted(true)
        return UIDropProposal(operation: .move)
    }

    func dropInteraction(_ interaction: UIDropInteraction, sessionDidExit session: UIDropSession) {
        (interaction.view as? SlotView)?.setHighlighted(false)
    }

    func dropInteraction(_ interaction: UIDropInteraction, sessionDidEnd session: UIDropSession) {
        (interaction.view as? SlotView)?.setHighlighted(false)
    }

    func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
        guard let slot = interaction.view as? SlotView else { return }
        slot.setHighlighted(false)
        // The dragged tile's instance ID travels as the drag item's localObject.
        if let id = session.localDragSession?.items.first?.localObject as? UUID {
            installTile(id, atSlot: slot.index)
        }
    }
}
