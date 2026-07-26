import RealityKit
import ILSHandTracking

@MainActor
public enum CockpitHandTracking {
    nonisolated(unsafe) public static var currentService: HandTrackingService?
}

public struct CockpitSimulationSetup {
    @MainActor
    public static func registerAll() {
        EmissiveButtonComponent.registerComponent()
        EmissiveButtonSystem.registerSystem()
        
        PanelVolumeComponent.registerComponent()
        LinearActuatorComponent.registerComponent()
        SnappingSwitchComponent.registerComponent()
        LeverComponent.registerComponent()
        JoystickComponent.registerComponent()
        RotationalKnobComponent.registerComponent()
        HandModelComponent.registerComponent()
        
        LinearActuatorSystem.registerSystem()
        SnappingSwitchSystem.registerSystem()
        LeverSystem.registerSystem()
        JoystickSystem.registerSystem()
        RotationalKnobSystem.registerSystem()
        HandTrackingSystem.registerSystem()
    }
}
