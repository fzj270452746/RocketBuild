//
//  SceneDelegate.swift
//  RocketBuild
//
//  Programmatic launch: builds the shared GameServices and hands them to the
//  RootCoordinator. No storyboard, no global state.
//

import UIKit

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
}
