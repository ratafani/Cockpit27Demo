import SwiftUI
import RealityKit
import RealityKitContent
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
                // Try Variation 1: The exported scene from immersivecockpit.reality
                let immersiveScene = try await Entity(named: "immersivecockpit", in: realityKitContentBundle)
                
                // Offset the scene so that its origin (0,0,0) aligns with the user's head.
                // Changed to 1.15 for seated perspective.
                immersiveScene.position = SIMD3<Float>(0.0, 1.15, 0.0) 
                
                setupCockpit(scene: immersiveScene)
                content.add(immersiveScene)
                print("Successfully loaded immersivecockpit scene.")
            } catch {
                print("Failed Variation 1: \(error)")
                do {
                    // Try Variation 2: world from immersivecockpit.reality if the root is named world
                    let worldScene = try await Entity(named: "world", in: realityKitContentBundle)
                    
                    // Offset the scene so that its origin (0,0,0) aligns with the user's head.
                    worldScene.position = SIMD3<Float>(0.0, 1.15, 0.0) 
                    
                    setupCockpit(scene: worldScene)
                    content.add(worldScene)
                    print("Successfully loaded world scene.")
                } catch {
                    print("Failed Variation 2: \(error)")
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
        .gesture(
            SpatialTapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    handleTap(entity: value.entity)
                }
        )
    }
    
    private func makeInteractable(_ entity: Entity) {
        // Generate a collision shape if none exists (this recursively creates one bounding box for the entire rig)
        entity.generateCollisionShapes(recursive: true)
        
        // Ensure the entity can receive gestures
        if entity.components[InputTargetComponent.self] == nil {
            // Restrict to `.direct` so the user must physically touch/collide with the entity to interact
            var input = InputTargetComponent()
            input.allowedInputTypes = .direct
            entity.components.set(input)
        }
    }
    
    private func setupCockpit(scene: Entity) {
        // Create an interaction component and attach it to the root scene entity
        var interaction = CockpitInteractionComponent()
        
        // Based on the RCP hierarchy screenshot:
        interaction.throttleEntity = scene.findEntity(named: "CP_ThrottleL_Lever_Rig_V01")
        interaction.sidestickEntity = scene.findEntity(named: "SC_SideStickL_Rig_V01")
        
        // Try to find the Skinned Mesh (ModelEntity) and joint for Sidestick
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
        
        if let throttle = interaction.throttleEntity {
            makeInteractable(throttle)
        }
        if let sidestick = interaction.sidestickEntity {
            makeInteractable(sidestick)
        }
        
        // Store for gesture reference
        scene.components.set(interaction)
        self.interactionEntity = scene
        
        // Setup buttons with the Emissive component
        if let buttonL = scene.findEntity(named: "CP_FireFaultL_Button_Rig_V01") {
            makeInteractable(buttonL)
            var emissiveComp = EmissiveButtonComponent()
            emissiveComp.targetEntities = findModelEntities(in: buttonL)
            buttonL.components.set(emissiveComp)
        }
        if let buttonR = scene.findEntity(named: "CP_FireFaultR_Button_Rig_V01") {
            makeInteractable(buttonR)
            var emissiveComp = EmissiveButtonComponent()
            emissiveComp.targetEntities = findModelEntities(in: buttonR)
            buttonR.components.set(emissiveComp)
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
    
    private func handleTap(entity: Entity) {
        print("👆 Tap detected on entity: \(entity.name)")
        
        // Because the collision shape might be on a child mesh, we need to traverse UP 
        // the hierarchy to find the parent Rig that holds our EmissiveButtonComponent.
        var currentEntity: Entity? = entity
        while let current = currentEntity {
            if var emissiveComponent = current.components[EmissiveButtonComponent.self] {
                print("🎯 Found EmissiveButtonComponent on \(current.name) - starting animation!")
                emissiveComponent.startAnimation()
                current.components.set(emissiveComponent)
                
                // Procedural physical button push: instantly move the button inwards on Z axis
                let originalPos = current.position
                current.position = originalPos + SIMD3<Float>(0, 0, -0.01) // Push in 1cm
                
                // Spring back out after a short delay
                Task {
                    try? await Task.sleep(nanoseconds: 150_000_000)
                    await MainActor.run {
                        current.position = originalPos
                    }
                }
                
                return
            }
            currentEntity = current.parent
        }
        print("⚠️ No EmissiveButtonComponent found in hierarchy of \(entity.name).")
    }
}
