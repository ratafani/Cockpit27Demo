import RealityKit
import ILSHandTracking
import Cockpit27Core

@MainActor
public enum CockpitHandTracking {
    nonisolated(unsafe) public static var currentService: HandTrackingService?
}

public struct CockpitSimulationSetup {
    @MainActor
    public static func registerAll() {
        // Register Live Hand Tracking Service into DI Container
        DependencyContainer.shared.register(HandTracking27ServiceProtocol.self, service: CockpitHandTrackingBridge())
        
        // Register Components
        EmissiveButtonComponent.registerComponent()
        PanelVolumeComponent.registerComponent()
        LinearActuatorComponent.registerComponent()
        SwitchComponent.registerComponent()
        LeverComponent.registerComponent()
        SideStickComponent.registerComponent()
        KnobComponent.registerComponent()
        HandModelComponent.registerComponent()
        CockpitControlTagComponent.registerComponent()
        
        // Register Systems
        EmissiveButtonSystem.registerSystem()
        LinearActuatorSystem.registerSystem()
        SwitchSystem.registerSystem()
        LeverSystem.registerSystem()
        SideStickSystem.registerSystem()
        KnobSystem.registerSystem()
        HandTrackingSystem.registerSystem()
        CockpitDebugTelemetrySystem.registerSystem()
    }
}
