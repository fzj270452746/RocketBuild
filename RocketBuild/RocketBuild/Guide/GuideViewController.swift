//
//  GuideViewController.swift
//  RocketBuild
//
//  The "How to Play" screen reached from the main menu. A scrollable, English
//  briefing that explains the core loop and — most importantly — spells out
//  exactly which mahjong tiles raise which rocket stats, so the player can read
//  the deck and shop with intent instead of guessing. Read-only and
//  self-contained: it derives every number straight from the live TileCatalog
//  so the text can never drift out of sync with the actual tile balance.
//

import UIKit

final class GuideViewController: UIViewController {

    var onBack: (() -> Void)?

    private let services: GameServices
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let backButton = UIButton(type: .system)

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
        buildScroll()
        buildContent()
    }

    private func buildBackground() {
        let gradient = CAGradientLayer()
        gradient.frame = UIScreen.main.bounds
        gradient.colors = [Palette.spaceTop.cgColor, Palette.spaceBottom.cgColor]
        view.layer.insertSublayer(gradient, at: 0)
    }

    private func buildHeader() {
        let title = UILabel()
        title.translatesAutoresizingMaskIntoConstraints = false
        title.text = "HOW TO PLAY"
        title.font = .systemFont(ofSize: 26, weight: .heavy)
        title.textColor = .white
        view.addSubview(title)

        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.setTitle("✕", for: .normal)
        backButton.titleLabel?.font = .systemFont(ofSize: 22, weight: .bold)
        backButton.setTitleColor(.white, for: .normal)
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        view.addSubview(backButton)

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            title.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            backButton.centerYAnchor.constraint(equalTo: title.centerYAnchor),
            backButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            backButton.widthAnchor.constraint(equalToConstant: 40),
            backButton.heightAnchor.constraint(equalToConstant: 40),
        ])
        titleAnchor = title.bottomAnchor
    }

    private var titleAnchor: NSLayoutYAxisAnchor!

    private func buildScroll() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = true
        view.addSubview(scrollView)

        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 18
        stack.alignment = .fill
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: titleAnchor, constant: 14),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 4),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -28),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])
    }

    // MARK: Content

    private func buildContent() {
        stack.addArrangedSubview(makeCard(
            title: "THE GOAL",
            body: """
            Build a mahjong-powered rocket and fly as high as you can. Every metre \
            climbed earns coins and XP. Spend coins in the Shop to pull new tiles, \
            level up to unlock more rocket slots, and push your best altitude higher.
            """))

        stack.addArrangedSubview(makeCard(
            title: "THE LOOP",
            body: """
            1.  BUILD & LAUNCH — fit tiles into your rocket's slots, then fly.
            2.  CLIMB — dodge hazards, grab pickups, ride your boosts.
            3.  EARN — altitude converts to coins and XP on landing.
            4.  COLLECT — buy gacha pulls in the Shop to grow your deck.
            """))

        stack.addArrangedSubview(makeCard(
            title: "YOUR DECK",
            body: """
            You start with 5 weak starter tiles. Every tile you pull from the Shop \
            is added permanently to your deck — inspect it any time from MY DECK on \
            the menu. Before each flight the game deals a random hand of 5 tiles \
            from your deck; you install those into your rocket's slots. A bigger, \
            higher-quality deck means stronger hands over time.
            """))

        // Data-driven suit rows so the numbers match the live catalog.
        stack.addArrangedSubview(makeSectionHeader("TILE STATS — NUMBERED SUITS"))
        stack.addArrangedSubview(makeCard(
            title: nil,
            body: """
            The three numbered suits each raise one rocket stat. The pip number \
            scales the bonus: higher pips give more power but weigh more, so a "1" \
            is light and cheap while a "9" is a heavy powerhouse.
            """))
        stack.addArrangedSubview(makeSuitRow(
            sampleID: "wan_9", accent: Palette.suit(.character),
            heading: "萬  CHARACTERS → FUEL",
            detail: fuelDetail(),
            note: "More fuel = a longer burn before you stall out."))
        stack.addArrangedSubview(makeSuitRow(
            sampleID: "bamboo_9", accent: Palette.suit(.bamboo),
            heading: "條  BAMBOO → THRUST",
            detail: thrustDetail(),
            note: "More thrust = faster ascent and quicker recovery."))
        stack.addArrangedSubview(makeSuitRow(
            sampleID: "dot_9", accent: Palette.suit(.dot),
            heading: "筒  DOTS → CONTROL",
            detail: controlDetail(),
            note: "More control = sharper steering, and the lightest suit."))

        // Honor tiles carry the active abilities.
        stack.addArrangedSubview(makeSectionHeader("HONOR TILES — ACTIVE POWERS"))
        stack.addArrangedSubview(makeCard(
            title: nil,
            body: """
            The seven honor tiles (three dragons + four winds) skip the stat grind \
            and bring marquee abilities instead. They are rarer and define your \
            rocket's playstyle.
            """))
        for row in honorRows() { stack.addArrangedSubview(row) }

        // Quality tiers.
        stack.addArrangedSubview(makeSectionHeader("QUALITY TIERS"))
        stack.addArrangedSubview(makeCard(
            title: nil,
            body: qualityBody()))
    }

    // MARK: Catalog-derived copy

    private func fuelDetail() -> String {
        guard let lo = services.catalog.definition("wan_1"),
              let hi = services.catalog.definition("wan_9") else { return "" }
        return String(format: "+%.0f fuel (1 pip) … +%.0f fuel (9 pip)",
                      lo.statContribution.fuel, hi.statContribution.fuel)
    }

    private func thrustDetail() -> String {
        guard let lo = services.catalog.definition("bamboo_1"),
              let hi = services.catalog.definition("bamboo_9") else { return "" }
        return String(format: "+%.1f thrust (1 pip) … +%.1f thrust (9 pip)",
                      lo.statContribution.speed, hi.statContribution.speed)
    }

    private func controlDetail() -> String {
        guard let lo = services.catalog.definition("dot_1"),
              let hi = services.catalog.definition("dot_9") else { return "" }
        return String(format: "+%.1f control (1 pip) … +%.1f control (9 pip)",
                      lo.statContribution.control, hi.statContribution.control)
    }

    /// One descriptive line per honor tile, pulled from the catalog abilities.
    private func honorRows() -> [UIView] {
        let honors: [(id: String, blurb: String)] = [
            ("dragon_white", "Deploys a shield that absorbs incoming hits."),
            ("dragon_green", "Widens pickup magnet range to vacuum up coins."),
            ("dragon_red",   "Detonates an explosion that clears nearby hazards."),
            ("wind_east",    "Radar — reveals hazards and pickups ahead."),
            ("wind_south",   "Speed boost — a burst of extra thrust."),
            ("wind_west",    "Repair kit — restores hull / shield mid-flight."),
            ("wind_north",   "Stability — steadier flight and better control."),
        ]
        return honors.compactMap { entry in
            guard let def = services.catalog.definition(entry.id) else { return nil }
            return makeSuitRow(
                sampleID: entry.id,
                accent: Palette.suit(.honor).withAlphaComponent(0.9),
                heading: def.displayName.uppercased() + "  " + def.glyph,
                detail: entry.blurb,
                note: nil)
        }
    }

    private func qualityBody() -> String {
        // Show the real power multipliers straight off TileQuality.
        let lines = TileQuality.allCases.map { q -> String in
            String(format: "•  %@ — ×%.2f power", q.rawValue.capitalized, q.powerScale)
        }.joined(separator: "\n")
        return """
        Any tile can drop at four qualities. Higher quality multiplies every \
        beneficial stat while keeping the same weight, so it is strictly better.

        \(lines)
        """
    }

    // MARK: Builders

    private func makeSectionHeader(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = .systemFont(ofSize: 15, weight: .heavy)
        l.textColor = Palette.coin
        return l
    }

    /// A rounded card with an optional bold title and a body paragraph.
    private func makeCard(title: String?, body: String) -> UIView {
        let card = UIView()
        card.backgroundColor = UIColor(white: 1, alpha: 0.06)
        card.layer.cornerRadius = 14

        let inner = UIStackView()
        inner.axis = .vertical
        inner.spacing = 6
        inner.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(inner)

        if let title {
            let t = UILabel()
            t.text = title
            t.font = .systemFont(ofSize: 16, weight: .heavy)
            t.textColor = .white
            inner.addArrangedSubview(t)
        }

        let b = UILabel()
        b.text = body
        b.numberOfLines = 0
        b.font = .systemFont(ofSize: 13.5, weight: .regular)
        b.textColor = UIColor(white: 0.88, alpha: 1)
        inner.addArrangedSubview(b)

        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            inner.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            inner.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            inner.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
        ])
        return card
    }

    /// A card with a sample tile face on the left and heading/detail on the right.
    private func makeSuitRow(sampleID: String, accent: UIColor,
                             heading: String, detail: String, note: String?) -> UIView {
        let card = UIView()
        card.backgroundColor = UIColor(white: 1, alpha: 0.06)
        card.layer.cornerRadius = 14

        // A slim accent stripe on the leading edge keys the row to its suit colour.
        let stripe = UIView()
        stripe.translatesAutoresizingMaskIntoConstraints = false
        stripe.backgroundColor = accent
        stripe.layer.cornerRadius = 2
        card.addSubview(stripe)

        let faceView = UIImageView()
        faceView.translatesAutoresizingMaskIntoConstraints = false
        faceView.contentMode = .scaleAspectFit
        if let def = services.catalog.definition(sampleID) {
            faceView.image = services.materials.tileFaceImage(
                glyph: def.glyph, suit: def.suit, quality: .common,
                cacheKey: def.faceCacheKey + "_guide")
        }
        card.addSubview(faceView)

        let text = UIStackView()
        text.axis = .vertical
        text.spacing = 3
        text.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(text)

        let h = UILabel()
        h.text = heading
        h.font = .systemFont(ofSize: 14, weight: .heavy)
        h.textColor = .white
        h.numberOfLines = 2
        text.addArrangedSubview(h)

        let d = UILabel()
        d.text = detail
        d.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        d.textColor = Palette.hud
        d.numberOfLines = 0
        text.addArrangedSubview(d)

        if let note {
            let n = UILabel()
            n.text = note
            n.font = .systemFont(ofSize: 12, weight: .regular)
            n.textColor = UIColor(white: 0.78, alpha: 1)
            n.numberOfLines = 0
            text.addArrangedSubview(n)
        }

        NSLayoutConstraint.activate([
            stripe.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stripe.topAnchor.constraint(equalTo: card.topAnchor),
            stripe.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            stripe.widthAnchor.constraint(equalToConstant: 4),

            faceView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            faceView.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            faceView.widthAnchor.constraint(equalToConstant: 52),
            faceView.heightAnchor.constraint(equalToConstant: 70),

            text.leadingAnchor.constraint(equalTo: faceView.trailingAnchor, constant: 14),
            text.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            text.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            text.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
        ])
        // Keep the card at least as tall as the face.
        faceView.topAnchor.constraint(greaterThanOrEqualTo: card.topAnchor, constant: 12).isActive = true
        faceView.bottomAnchor.constraint(lessThanOrEqualTo: card.bottomAnchor, constant: -12).isActive = true
        return card
    }

    @objc private func backTapped() {
        services.audio.play(.coin)
        onBack?()
    }
}
