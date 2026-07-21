import RealityKit

public struct CockpitSimulationSetup {
    public static func registerAll() {
        CockpitInteractionComponent.registerComponent()
        EmissiveButtonComponent.registerComponent()
        CockpitInteractionSystem.registerSystem()
        EmissiveButtonSystem.registerSystem()
    }
}
