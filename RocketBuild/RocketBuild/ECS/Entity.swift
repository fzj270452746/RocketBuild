//
//  Entity.swift
//  RocketBuild
//
//  A very small entity/component core. Nodes only carry models; behaviour lives
//  in components attached to entities. This avoids deep SCNNode subclassing.
//

import SceneKit

/// Marker protocol for anything that can update itself each frame.
protocol Component: AnyObject {
    func update(_ ctx: ComponentContext)
    /// Called once when the owning entity is torn down.
    func onDetach()
}

extension Component {
    func onDetach() {}
}

/// Per-frame data handed to components. Passed by reference so components can
/// read shared flight state without any global singleton.
final class ComponentContext {
    let deltaTime: Float
    let elapsedTime: TimeInterval
    /// The flight context, when a component runs inside the flight scene.
    weak var flight: FlightContext?

    init(deltaTime: Float, elapsedTime: TimeInterval, flight: FlightContext?) {
        self.deltaTime = deltaTime
        self.elapsedTime = elapsedTime
        self.flight = flight
    }
}

/// An entity is a node plus a bag of components keyed by type.
final class Entity {
    let node: SCNNode
    private(set) var components: [Component] = []
    private var byType: [ObjectIdentifier: Component] = [:]

    init(node: SCNNode = SCNNode()) {
        self.node = node
    }

    @discardableResult
    func add(_ component: Component) -> Entity {
        components.append(component)
        byType[ObjectIdentifier(type(of: component))] = component
        return self
    }

    func component<T: Component>(_ type: T.Type) -> T? {
        byType[ObjectIdentifier(type)] as? T
    }

    func update(_ ctx: ComponentContext) {
        for c in components { c.update(ctx) }
    }

    func destroy() {
        for c in components { c.onDetach() }
        components.removeAll()
        byType.removeAll()
        node.removeFromParentNode()
    }
}
