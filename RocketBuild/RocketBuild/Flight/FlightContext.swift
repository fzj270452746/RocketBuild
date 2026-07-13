//
//  FlightContext.swift
//  RocketBuild
//
//  Per-run state for the flight scene. Injected into the scene and its systems
//  (no global GameManager). Modules mutate the "requested" fields each frame;
//  the flight loop reads them to drive movement, then resets the transient ones.
//

import SceneKit

/// Visual effects a module can request without knowing about the scene graph.
enum FlightEffect {
    case shieldRipple
    case boostFlash
    case explosion(SCNVector3)
    case coinBurst(SCNVector3)
}

/// Physics collision categories (bit masks).
struct PhysicsCategory {
    static let rocket: Int  = 1 << 0
    static let hazard: Int  = 1 << 1
    static let pickup: Int  = 1 << 2
}

/// Difficulty bands keyed on altitude, per the design table.
enum DifficultyBand: String {
    case slow, medium, fast, chaos, extreme

    static func band(forAltitude m: Double) -> DifficultyBand {
        switch m {
        case ..<1000:   return .slow
        case ..<3000:   return .medium
        case ..<5000:   return .fast
        case ..<10000:  return .chaos
        default:        return .extreme
        }
    }

    /// Spawn interval scale (smaller = more frequent).
    var spawnScale: Double {
        switch self {
        case .slow: return 1.6
        case .medium: return 1.2
        case .fast: return 0.9
        case .chaos: return 0.65
        case .extreme: return 0.45
        }
    }
}

final class FlightContext {

    // Injected collaborators.
    let rocket: RocketBody
    let stats: RocketStats

    // Live run state.
    private(set) var altitude: Double = 0
    private(set) var coins: Int = 0
    private(set) var energy: Double
    var fuel: Double
    private(set) var hullHealth: Double = 100

    // Combo.
    private(set) var comboCount: Int = 0
    private(set) var multiplier: Int = 1
    private(set) var score: Int = 0

    // Transient per-frame requests written by modules, reset after each update.
    var thrust: Float = 0
    var controlBonus: Float = 0
    var stability: Float = 0
    var speedMultiplier: Float = 1
    var magnetRadius: Double = 0
    var radarRange: Float = 0
    var meteorDetection = false

    // Persisted-ish ability state.
    var shieldCharge: Double = 0

    // Hooks the scene installs to react to module requests.
    var onEffect: ((FlightEffect) -> Void)?
    var onDetonate: ((Float) -> Void)?

    init(rocket: RocketBody) {
        self.rocket = rocket
        self.stats = rocket.stats
        self.fuel = rocket.maxFuel
        self.energy = rocket.stats.energyCapacity
        self.shieldCharge = rocket.stats.shield
    }

    var maxFuel: Double { rocket.maxFuel }
    var maxEnergy: Double { max(1, stats.energyCapacity) }
    var isAlive: Bool { hullHealth > 0 && fuel > 0 }
    var difficulty: DifficultyBand { .band(forAltitude: altitude) }

    // MARK: Module-facing API

    func requestEffect(_ effect: FlightEffect) { onEffect?(effect) }

    func detonate(radius: Float) { onDetonate?(radius) }

    func repairHull(by amount: Double) {
        hullHealth = min(100, hullHealth + amount)
    }

    func repairModules(by amount: Double) {
        for m in rocket.modules where !m.isFunctional {
            m.heal(amount)
        }
    }

    // MARK: Loop-facing mutation

    func resetTransientRequests() {
        thrust = 0
        controlBonus = 0
        stability = 0
        speedMultiplier = 1
        magnetRadius = 0
        radarRange = 0
        meteorDetection = false
    }

    func addAltitude(_ delta: Double) {
        altitude += delta
        // Score follows altitude, scaled by the active combo multiplier.
        score = Int(altitude) + comboBonus
    }

    func consumeFuel(_ amount: Double) { fuel = max(0, fuel - amount) }

    func refuel(_ amount: Double) { fuel = min(maxFuel, fuel + amount) }

    func addEnergy(_ amount: Double) { energy = min(maxEnergy, energy + amount) }

    func addCoins(_ n: Int) { coins += n }

    func damageHull(_ amount: Double) {
        // Shield soaks damage first.
        if shieldCharge > 0 {
            let absorbed = min(shieldCharge, amount)
            shieldCharge -= absorbed
            let remainder = amount - absorbed
            hullHealth = max(0, hullHealth - remainder)
        } else {
            hullHealth = max(0, hullHealth - amount)
        }
        breakCombo()
    }

    // MARK: Combo

    private var comboBonus = 0

    func registerDodge(perfect: Bool) {
        comboCount += 1
        comboBonus += (perfect ? 30 : 10) * multiplier
        // Ramp multiplier along the x2 / x3 / x5 track from the doc.
        switch comboCount {
        case 12...: multiplier = 5
        case 6...:  multiplier = 3
        case 3...:  multiplier = 2
        default:    multiplier = 1
        }
        score = Int(altitude) + comboBonus
    }

    func breakCombo() {
        comboCount = 0
        multiplier = 1
    }
}
