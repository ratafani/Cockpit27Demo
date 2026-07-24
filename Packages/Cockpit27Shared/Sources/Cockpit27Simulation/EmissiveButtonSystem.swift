import RealityKit
import Foundation
import UIKit

@MainActor
public class EmissiveButtonSystem: System {
    private static let query = EntityQuery(where: .has(EmissiveButtonComponent.self))
    
    public required init(scene: RealityKit.Scene) {}
    
    public func update(context: SceneUpdateContext) {
        let entities = context.scene.performQuery(Self.query)
        
        for entity in entities {
            guard var component = entity.components[EmissiveButtonComponent.self] else { continue }
            
            guard component.isAnimating else { continue }
            
            component.elapsedTime += context.deltaTime
            
            let progress = Float(min(1.0, component.elapsedTime / component.duration))
            // Smoothstep curve for natural switch animation
            let smoothProgress = progress * progress * (3.0 - 2.0 * progress)
            
            component.currentEmissiveValue = component.startEmissiveValue + (component.targetEmissiveValue - component.startEmissiveValue) * smoothProgress
            
            // Fallback: if targetEntities is empty, dynamically locate child model entities
            let targetsToUpdate = component.targetEntities.isEmpty ? findModelEntities(in: entity) : component.targetEntities
            
            print("💡 [EmissiveButtonSystem] Updating \(entity.name) -> intensity: \(component.currentEmissiveValue), targets count: \(targetsToUpdate.count)")
            
            for target in targetsToUpdate {
                applyEmissiveTrigger(to: target, intensity: component.currentEmissiveValue)
            }
            
            if component.elapsedTime >= component.duration {
                component.currentEmissiveValue = component.targetEmissiveValue
                component.isAnimating = false
                print("🏁 [EmissiveButtonSystem] Animation complete for \(entity.name), final value: \(component.currentEmissiveValue)")
            }
            
            entity.components.set(component)
        }
    }
    
    private func applyEmissiveTrigger(to entity: Entity, intensity: Float) {
        guard var modelComponent = entity.components[ModelComponent.self] else {
            print("⚠️ [EmissiveButtonSystem] Entity '\(entity.name)' has no ModelComponent!")
            return
        }
        
        var updatedMaterials = modelComponent.materials
        var modified = false
        
        for (i, mat) in updatedMaterials.enumerated() {
            let matType = String(describing: type(of: mat))
            print("🎨 [EmissiveButtonSystem] Target '\(entity.name)' material[\(i)] type: \(matType)")
            
            if var shaderMat = mat as? ShaderGraphMaterial {
                let possibleNames = [
                    "EmissiveTrigger",
                    "inputs:EmissiveTrigger",
                    "emissiveTrigger",
                    "inputs:emissiveTrigger",
                    "Emissive",
                    "inputs:Emissive",
                    "emissive",
                    "inputs:emissive",
                    "EmissiveIntensity",
                    "inputs:EmissiveIntensity",
                    "EmissiveColor",
                    "inputs:EmissiveColor"
                ]
                
                var successCount = 0
                for paramName in possibleNames {
                    do {
                        try shaderMat.setParameter(name: paramName, value: .float(intensity))
                        successCount += 1
                    } catch {
                        // ignore parameter name mismatches
                    }
                }
                
                if successCount > 0 {
                    print("✅ [EmissiveButtonSystem] ShaderGraphMaterial on '\(entity.name)' set \(successCount) parameter(s) to \(intensity)")
                    updatedMaterials[i] = shaderMat
                    modified = true
                } else {
                    print("⚠️ [EmissiveButtonSystem] ShaderGraphMaterial setParameter failed for all candidate names on '\(entity.name)'")
                }
            } else if var pbr = mat as? PhysicallyBasedMaterial {
                pbr.emissiveColor = .init(color: UIColor(red: 1.0, green: 0.7, blue: 0.1, alpha: 1.0))
                pbr.emissiveIntensity = intensity
                updatedMaterials[i] = pbr
                modified = true
                print("✅ [EmissiveButtonSystem] PhysicallyBasedMaterial on '\(entity.name)' set emissiveIntensity to \(pbr.emissiveIntensity)")
            } else if var unlit = mat as? UnlitMaterial {
                unlit.color = .init(tint: UIColor(red: 1.0, green: 0.7, blue: 0.1, alpha: CGFloat(intensity)))
                updatedMaterials[i] = unlit
                modified = true
                print("✅ [EmissiveButtonSystem] UnlitMaterial on '\(entity.name)' set color tint alpha to \(intensity)")
            } else if var simple = mat as? SimpleMaterial {
                simple.color = .init(tint: UIColor(red: 1.0, green: 0.7, blue: 0.1, alpha: CGFloat(intensity)))
                updatedMaterials[i] = simple
                modified = true
                print("✅ [EmissiveButtonSystem] SimpleMaterial on '\(entity.name)' set color tint alpha to \(intensity)")
            } else {
                print("⚠️ [EmissiveButtonSystem] Unknown/Generic Material type '\(matType)' on '\(entity.name)'")
            }
        }
        
        if modified {
            modelComponent.materials = updatedMaterials
            entity.components.set(modelComponent)
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
