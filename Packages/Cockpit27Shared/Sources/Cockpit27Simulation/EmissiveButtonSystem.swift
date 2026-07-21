import RealityKit
import Foundation

public class EmissiveButtonSystem: System {
    private static let query = EntityQuery(where: .has(EmissiveButtonComponent.self))
    
    public required init(scene: RealityKit.Scene) {}
    
    public func update(context: SceneUpdateContext) {
        let entities = context.scene.performQuery(Self.query)
        
        for entity in entities {
            var component = entity.components[EmissiveButtonComponent.self]!
            
            guard component.isAnimating else { continue }
            
            component.elapsedTime += context.deltaTime
            
            let progress = Float(1.0 - (component.elapsedTime / component.duration))
            let clampedProgress = max(0.0, min(1.0, progress))
            
            // Update the ShaderGraphMaterial on all target entities
            for target in component.targetEntities {
                applyEmissiveTrigger(to: target, progress: clampedProgress)
            }
            
            if component.elapsedTime >= component.duration {
                component.isAnimating = false
            }
            
            entity.components.set(component)
        }
    }
    
    private func applyEmissiveTrigger(to entity: Entity, progress: Float) {
        if var modelComponent = entity.components[ModelComponent.self],
           var material = modelComponent.materials.first as? ShaderGraphMaterial {
            do {
                try material.setParameter(name: "inputs:EmissiveTrigger", value: .float(progress))
                modelComponent.materials[0] = material
                entity.components.set(modelComponent)
            } catch {
                // Suppress error
            }
        }
    }
}
