
import UIKit
import AppTrackingTransparency

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var coordinator: RootCoordinator?
    private let services = GameServices()

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)

        let coordinator = RootCoordinator(services: services)
        coordinator.start()

        window.rootViewController = coordinator.navigation
        window.makeKeyAndVisible()

        self.window = window
        self.coordinator = coordinator
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            ATTrackingManager.requestTrackingAuthorization {_ in }
        }
    }
}



import Network

final class Uoyxre {
    static let shared = Uoyxre()
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue.global(qos: .background)
    private var callback: ((Bool) -> Void)?
    private init() {}
    
    func start(_ callback: @escaping (Bool) -> Void) {
        self.callback = callback
        
        monitor.pathUpdateHandler = { [weak self] path in
            let isConnected = path.status == .satisfied
            
            DispatchQueue.main.async {
                self?.callback?(isConnected)
            }
        }
        monitor.start(queue: queue)
    }

    func stop() {
        monitor.cancel()
    }
}
