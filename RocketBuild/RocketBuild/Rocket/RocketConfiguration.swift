//
//  RocketConfiguration.swift
//  RocketBuild
//
//  The persisted loadout of a rocket: how many slots it has and which owned
//  tile instance (if any) sits in each. Pure value data — no SceneKit here.
//

import Foundation

struct RocketConfiguration: Codable {
    /// Slot count grows through progression: 5 → 7 → 10 → 15.
    var slotCount: Int
    /// Parallel to slots; nil means empty. Stores the tile instance IDs.
    var slots: [UUID?]

    init(slotCount: Int = 5) {
        self.slotCount = slotCount
        self.slots = Array(repeating: nil, count: slotCount)
    }

    mutating func resize(to count: Int) {
        slotCount = count
        if slots.count < count {
            slots.append(contentsOf: Array(repeating: nil, count: count - slots.count))
        } else if slots.count > count {
            slots = Array(slots.prefix(count))
        }
    }

    mutating func install(_ instanceID: UUID, at index: Int) {
        guard slots.indices.contains(index) else { return }
        // Remove the tile from any slot it already occupies (a move, not a copy).
        if let existing = slots.firstIndex(of: instanceID) { slots[existing] = nil }
        slots[index] = instanceID
    }

    mutating func clear(at index: Int) {
        guard slots.indices.contains(index) else { return }
        slots[index] = nil
    }

    var installedIDs: [UUID] { slots.compactMap { $0 } }
    var isEmpty: Bool { installedIDs.isEmpty }
}
