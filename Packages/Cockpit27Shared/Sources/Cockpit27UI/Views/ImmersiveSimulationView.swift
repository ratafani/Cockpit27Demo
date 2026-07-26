import SwiftUI
import RealityKit
import RealityKitContent
import Cockpit27Domain
import Cockpit27Simulation
import ILSHandTracking

public struct ImmersiveSimulationView: View {
    @Binding var showGloves: Bool
    @Binding var hidePhysicalHand: Bool
    var onExit: () -> Void
    
    // Track the interaction root
    @State private var interactionEntity: Entity?
    @State private var handsEntity: HandsEntity?
    
    public init(showGloves: Binding<Bool>, hidePhysicalHand: Binding<Bool>, onExit: @escaping () -> Void) {
        self._showGloves = showGloves
        self._hidePhysicalHand = hidePhysicalHand
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
                
                // Load Hands
                let leftGlove = try? await ModelEntity(contentsOf: Bundle.module.url(forResource: "LeftGlove", withExtension: "usdz")!)
                let rightGlove = try? await ModelEntity(contentsOf: Bundle.module.url(forResource: "RightGlove", withExtension: "usdz")!)
                
                let handsEntity = HandsEntity(leftGlove: leftGlove, rightGlove: rightGlove)
                content.add(handsEntity)
                self.handsEntity = handsEntity
                
                
            } catch {
                print("⚠️ Failed loading 'updatedcockpit' directly: \(error)")
                do {
                    // Fallback: try loading "Cockpit_A320" or "world" if named differently in scene package
                    let fallbackScene = try await Entity(named: "Cockpit_A320", in: realityKitContentBundle)
                    fallbackScene.position = .zero 
                    
                    setupCockpit(scene: fallbackScene)
                    content.add(fallbackScene)
                    print("✅ Successfully loaded Cockpit_A320 fallback scene.")
                    
                    // Load Hands
                    let leftGlove = try? await ModelEntity(contentsOf: Bundle.module.url(forResource: "LeftGlove", withExtension: "usdz")!)
                    let rightGlove = try? await ModelEntity(contentsOf: Bundle.module.url(forResource: "RightGlove", withExtension: "usdz")!)
                    
                    let handsEntity = HandsEntity(leftGlove: leftGlove, rightGlove: rightGlove)
                    content.add(handsEntity)
                    self.handsEntity = handsEntity
                } catch {
                    print("❌ Failed loading fallback scene: \(error)")
                }
            }
        } update: { content in
            if let handsEntity = handsEntity {
                handsEntity.isEnabled = showGloves
            }
        }
        .task {
            // Re-instantiate HandTrackingService on every entrance to prevent ARKit session reuse crash
            let service = HandTrackingService()
            CockpitHandTracking.currentService = service
            do {
                try await service.start()
            } catch {
                print("Failed to start hand tracking: \(error)")
            }
        }
        .onDisappear {
            CockpitHandTracking.currentService?.stop()
            CockpitHandTracking.currentService = nil
        }
        .upperLimbVisibility(hidePhysicalHand ? .hidden : .visible)
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
        // Initialize the domain model and apply spatial components
        var model = CockpitModel()
        model.populate(from: scene)
        model.configureSpatialActuators()
        
        // Keep exact (0,0,0) scene position as configured in RCP
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
