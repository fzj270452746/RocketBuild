//
//  SaveStore.swift
//  RocketBuild
//
//  Reads/writes the SaveData profile to a JSON file in Application Support.
//  Injected wherever persistence is needed instead of a global singleton.
//

import Foundation

final class SaveStore {

    private let url: URL
    private let catalog: TileCatalog
    private(set) var data: SaveData

    init(catalog: TileCatalog, filename: String = "profile.json",
         fileManager: FileManager = .default) {
        self.catalog = catalog
        let dir = (try? fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                        appropriateFor: nil, create: true))
            ?? fileManager.temporaryDirectory
        self.url = dir.appendingPathComponent(filename)

        if let loaded = Self.load(from: url) {
            self.data = loaded
        } else {
            self.data = SaveData.newProfile(catalog: catalog)
            persist()
        }
    }

    // MARK: Mutation helpers

    func update(_ mutate: (inout SaveData) -> Void) {
        mutate(&data)
        persist()
    }

    func recordRun(result: RunResult, hazardsDestroyed: Int = 0) {
        update { d in
            d.bestHeight = max(d.bestHeight, result.altitude)
            d.coins += result.coins
            d.statistics.totalRuns += 1
            d.statistics.totalCoinsEarned += result.coins
            d.statistics.totalDistance += result.altitude
            d.statistics.hazardsDestroyed += hazardsDestroyed
        }
    }

    /// Inventory keyed by instance ID for quick lookup during assembly/flight.
    var inventory: [UUID: TileInstance] {
        Dictionary(uniqueKeysWithValues: data.ownedTiles.map { ($0.instanceID, $0) })
    }

    // MARK: I/O

    private func persist() {
        do {
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: url, options: .atomic)
        } catch {
            #if DEBUG
            print("SaveStore: failed to persist — \(error)")
            #endif
        }
    }

    private static func load(from url: URL) -> SaveData? {
        guard let raw = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(SaveData.self, from: raw)
    }
}
