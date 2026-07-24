import SwiftUI
import RealityKit
import RealityKitContent
import Cockpit27Domain
import Cockpit27Simulation
import ILSHandTracking

public struct ImmersiveSimulationView: View {
    var onExit: () -> Void
    
    // Track the interaction root
    @State private var interactionEntity: Entity?
    
    public init(onExit: @escaping () -> Void) {
        self.onExit = onExit
        // Register ECS components and systems on initialization
        CockpitSimulationSetup.registerAll()
    }
    
    public var body: some View {
        RealityView { content in
            do {
                // Primary: Load updatedcockpit.reality scene
                let cockpitScene = try await Entity(named: "updatedcockpit", in: realityKitContentBundle)
                
                // Align RCP origin (0,0,0) directly with the user's initial head position (0,0,0 in VisionOS)
                cockpitScene.position = .zero 
                
                setupCockpit(scene: cockpitScene)
                content.add(cockpitScene)
                print("✅ Successfully loaded updatedcockpit scene.")
            } catch {
                print("⚠️ Failed loading 'updatedcockpit' directly: \(error)")
                do {
                    // Fallback: try loading "Cockpit_A320" or "world" if named differently in scene package
                    let fallbackScene = try await Entity(named: "Cockpit_A320", in: realityKitContentBundle)
                    fallbackScene.position = .zero 
                    
                    setupCockpit(scene: fallbackScene)
                    content.add(fallbackScene)
                    print("✅ Successfully loaded Cockpit_A320 fallback scene.")
                } catch {
                    print("❌ Failed loading fallback scene: \(error)")
                }
            }
        }
        .task {
            do {
                try await HandTrackingService.shared.start()
            } catch {
                print("Failed to start hand tracking: \(error)")
            }
        }
        .onDisappear {
            HandTrackingService.shared.stop()
        }
    }
    
    private func makeInteractable(_ entity: Entity) {
        // Generate a collision shape if none exists (recursively creates bounding box for the entity rig)
        entity.generateCollisionShapes(recursive: true)
        
        // Ensure the entity can receive direct touch gestures
        if entity.components[InputTargetComponent.self] == nil {
            var input = InputTargetComponent()
            input.allowedInputTypes = .direct
            entity.components.set(input)
        }
    }
    
    private func setupCockpit(scene: Entity) {
        // Create an interaction component and attach it to the root scene entity
        var interaction = CockpitInteractionComponent()
        
        // Match hierarchy from RCP (updatedcockpit -> Cockpit_A320 -> root -> Sidestick / Throttle 1):
        let throttleL = scene.findEntity(named: CockpitModel.EntityNames.throttleLeft)
            ?? scene.findEntity(named: "CP_ThrottleL_Lever_Rig_V01")
            ?? scene.findEntity(named: CockpitModel.EntityNames.throttleLegacyFallback)
        let throttleR = scene.findEntity(named: CockpitModel.EntityNames.throttleRight)
            ?? scene.findEntity(named: "CP_ThrottleR_Lever_Rig_V01")
        
        interaction.throttleEntity = throttleL
        interaction.throttleRightEntity = throttleR
        
        let sidestickRig = scene.findEntity(named: CockpitModel.EntityNames.sidestick)
            ?? scene.findEntity(named: "SC_SideStickL_Rig_V01")
            ?? scene.findEntity(named: "SC_SideStickL_Rig_V01_001")
        interaction.sidestickEntity = sidestickRig

        // Check for Skinned Mesh (ModelEntity) and joint for Sidestick
        if let root = interaction.sidestickEntity {
            var modelEntity: ModelEntity? = nil
            var queue: [Entity] = [root]
            while !queue.isEmpty {
                let current = queue.removeFirst()
                if let model = current as? ModelEntity, !model.jointNames.isEmpty {
                    modelEntity = model
                    break
                }
                queue.append(contentsOf: current.children)
            }
            
            if let model = modelEntity, !model.jointNames.isEmpty {
                interaction.sidestickModelEntity = model
                
                if let index = model.jointNames.firstIndex(where: { $0.lowercased().contains("stick") }) {
                    interaction.sidestickJointIndex = index
                } else if model.jointNames.count > 1 {
                    interaction.sidestickJointIndex = model.jointNames.count - 1
                } else {
                    interaction.sidestickJointIndex = 0
                }
            }
        }
        
        if let buttonRigRoot = scene.findEntity(named: "SC_SideStickL_Button_Rig_V01") {
            interaction.buttonRigEntity = buttonRigRoot
            interaction.initialButtonRigRotation = buttonRigRoot.transform.rotation
        }
        
        // Make throttles and sidestick interactable with collision + input targets
        if let throttle = interaction.throttleEntity {
            makeInteractable(throttle)
        }
        if let throttleR = interaction.throttleRightEntity {
            makeInteractable(throttleR)
        }
        if let sidestick = interaction.sidestickEntity {
            makeInteractable(sidestick)
        }
        
        // Keep exact (0,0,0) scene position as configured in RCP
        
        // Store component on root scene entity for System and gesture queries
        scene.components.set(interaction)
        self.interactionEntity = scene
        
        // Setup interactive buttons on Central Pedestal with Emissive components
        let buttonNames = CockpitModel.EntityNames.pedestalInteractableNames + [
            "CP_FireFaultL_Button_Rig_V01",
            "CP_FireFaultR_Button_Rig_V01",
            "CP_ENG1_Switch_Rig_V01",
            "CP_ENG2_Switch_Rig_V01",
            "CP_EngineMode_Rotate_Rig_V01",
            "CP_PitchTrimL_Rotate_Rig_V01",
            "CP_PitchTrimR_Rotate_Rig_V01"
        ]
        
        for name in buttonNames {
            if let btn = scene.findEntity(named: name) {
                makeInteractable(btn)
                var emissiveComp = EmissiveButtonComponent()
                let modelEntities = findModelEntities(in: btn)
                emissiveComp.targetEntities = modelEntities
                btn.components.set(emissiveComp)
                print("🔘 [setupCockpit] Registered button '\(btn.name)' with \(modelEntities.count) target ModelEntities")
            }
        }
    }
    
    private func findModelEntities(in root: Entity) -> [Entity] {
        var results = [Entity]()
        if root.components[ModelComponent.self] != nil {
            results.append(root)
        }
        for child in root.children {
            results.append(contentsOf: findModelEntities(in: child))
        }
        return results
    }
}
