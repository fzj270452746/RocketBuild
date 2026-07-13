
import UIKit

final class RootCoordinator {

    let navigation = UINavigationController()
    private let services: GameServices

    init(services: GameServices) {
        self.services = services
        navigation.setNavigationBarHidden(true, animated: false)
        navigation.overrideUserInterfaceStyle = .dark
    }

    func start() {
        let menu = makeMenu()
        navigation.setViewControllers([menu], animated: false)
        // Debug entry points for automated smoke testing (no effect in normal use).
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-uitest-flight") {
            showFlight(configuration: services.store.data.configuration)
        } else if args.contains("-uitest-assembly") {
            showAssembly()
        } else if args.contains("-uitest-shop") {
            showShop()
        } else if args.contains("-uitest-guide") {
            showGuide()
        }
    }

    // MARK: Screen factories

    private func makeMenu() -> UIViewController {
        let vc = MenuViewController(services: services)
        vc.onPlay = { [weak self] in self?.showAssembly() }
        vc.onShop = { [weak self] in self?.showShop() }
        vc.onDeck = { [weak self] in self?.showDeck() }
        vc.onGuide = { [weak self] in self?.showGuide() }
        return vc
    }

    private func showShop() {
        let vc = ShopViewController(services: services)
        vc.onBack = { [weak self] in self?.navigation.popViewController(animated: true) }
        navigation.pushViewController(vc, animated: true)
    }

    private func showDeck() {
        let vc = DeckViewController(services: services)
        vc.onBack = { [weak self] in self?.navigation.popViewController(animated: true) }
        navigation.pushViewController(vc, animated: true)
    }

    private func showGuide() {
        let vc = GuideViewController(services: services)
        vc.onBack = { [weak self] in self?.navigation.popViewController(animated: true) }
        navigation.pushViewController(vc, animated: true)
    }

    private func showAssembly() {
        let vc = AssemblyViewController(services: services)
        vc.onLaunch = { [weak self] configuration in
            self?.showFlight(configuration: configuration)
        }
        vc.onBack = { [weak self] in self?.navigation.popViewController(animated: true) }
        navigation.pushViewController(vc, animated: true)
    }

    private func showFlight(configuration: RocketConfiguration) {
        let vc = FlightViewController(services: services,
                                     configuration: configuration,
                                     inventory: services.store.inventory)
        vc.delegate = self
        navigation.pushViewController(vc, animated: true)
    }
}

extension RootCoordinator: FlightViewControllerDelegate {
    func flightDidEnd(result: RunResult) {
        services.store.recordRun(result: result)
        // Distance earns experience toward the next level (and, at milestone
        // levels, an extra rocket slot).
        let xp = max(0, Int(result.altitude / 10))
        let levelUp = services.progression.awardExperience(xp)
        // Return to the menu and present the result summary.
        navigation.popToRootViewController(animated: true)
        if let menu = navigation.viewControllers.first as? MenuViewController {
            menu.presentResult(result, xpGained: xp, levelUp: levelUp)
        }
    }
}
