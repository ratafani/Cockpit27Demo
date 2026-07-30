import Foundation
import RealityKit
import Cockpit27Core

/// Centralized system for querying all CockpitControlTagComponent entities, providing real-time logging & debugging
@MainActor
public class CockpitDebugTelemetrySystem: System {
    private static let query = EntityQuery(where: .has(CockpitControlTagComponent.self))
    
    private let telemetryService: Cockpit27TelemetryProtocol
    private var lastReportTime: Double = 0
    
    public required init(scene: RealityKit.Scene) {
        self.telemetryService = DependencyContainer.shared.resolve(Cockpit27TelemetryProtocol.self)
    }
    
    public func update(context: SceneUpdateContext) {
        // Query active tagged controls for debugging / verification
        for entity in context.scene.performQuery(Self.query) {
            guard let tag = entity.components[CockpitControlTagComponent.self] else { continue }
            
            if tag.isDebugHighlighted {
                // Future visual debugging overlay logic can be injected here
            }
        }
    }
}
