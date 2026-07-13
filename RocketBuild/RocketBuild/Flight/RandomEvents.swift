//
//  RandomEvents.swift
//  RocketBuild
//
//  Endless events that reshape a run every 30–60s (meteor shower, low gravity,
//  coin rain, etc). Modelled as data + a closure so adding an event does not
//  require touching a switch in the flight loop.
//

import Foundation

struct RandomEvent {
    let name: String
    let duration: TimeInterval
    /// Tuning knobs the flight loop reads while the event is active.
    let spawnRateMultiplier: Double
    let gravityScale: Double
    let coinBias: Double
    let hazardBias: Double
}

/// Selects and times endless events without global state.
final class EventDirector {

    private let pool: [RandomEvent]
    private var timeUntilNext: TimeInterval
    private(set) var active: RandomEvent?
    private var activeRemaining: TimeInterval = 0

    /// Callback so the HUD/scene can announce an event banner.
    var onEventBegan: ((RandomEvent) -> Void)?
    var onEventEnded: (() -> Void)?

    init() {
        pool = [
            RandomEvent(name: "Meteor Shower", duration: 8, spawnRateMultiplier: 2.2,
                        gravityScale: 1, coinBias: 0.5, hazardBias: 2.5),
            RandomEvent(name: "Solar Storm", duration: 7, spawnRateMultiplier: 1.6,
                        gravityScale: 1, coinBias: 0.3, hazardBias: 1.8),
            RandomEvent(name: "Satellite Belt", duration: 9, spawnRateMultiplier: 1.4,
                        gravityScale: 1, coinBias: 0.5, hazardBias: 1.6),
            RandomEvent(name: "Low Gravity", duration: 10, spawnRateMultiplier: 0.9,
                        gravityScale: 0.5, coinBias: 1, hazardBias: 0.8),
            RandomEvent(name: "Coin Rain", duration: 8, spawnRateMultiplier: 1.0,
                        gravityScale: 1, coinBias: 4, hazardBias: 0.4),
            RandomEvent(name: "Dark Zone", duration: 7, spawnRateMultiplier: 1.3,
                        gravityScale: 1, coinBias: 0.6, hazardBias: 1.5),
        ]
        timeUntilNext = TimeInterval.random(in: 30...60)
    }

    func update(dt: TimeInterval) {
        if active != nil {
            activeRemaining -= dt
            if activeRemaining <= 0 {
                active = nil
                onEventEnded?()
                timeUntilNext = TimeInterval.random(in: 30...60)
            }
            return
        }
        timeUntilNext -= dt
        if timeUntilNext <= 0, let picked = pool.randomElement() {
            active = picked
            activeRemaining = picked.duration
            onEventBegan?(picked)
        }
    }
}
