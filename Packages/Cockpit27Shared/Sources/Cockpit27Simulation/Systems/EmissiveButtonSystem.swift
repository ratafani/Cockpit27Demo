import RealityKit
import ARKit
import Foundation
import UIKit
import ILSHandTracking

@MainActor
public class EmissiveButtonSystem: System {
    private static let query = EntityQuery(where: .has(EmissiveButtonComponent.self))
    
    public required init(scene: RealityKit.Scene) {}
    
    public func update(context: SceneUpdateContext) {
        let entities = context.scene.performQuery(Self.query)
        
        let rightHand = CockpitHandTracking.currentService?.latestRightHand
        let leftHand = CockpitHandTracking.currentService?.latestLeftHand
        
        var indexTips = [SIMD3<Float>]()
        
        if let right = rightHand, right.isTracked, let skeleton = right.handSkeleton {
            let tipJoint = skeleton.joint(.indexFingerTip)
            let col = (right.originFromAnchorTransform * tipJoint.anchorFromJointTransform).columns.3
            indexTips.append(SIMD3<Float>(col.x, col.y, col.z))
        }
        
        if let left = leftHand, left.isTracked, let skeleton = left.handSkeleton {
            let tipJoint = skeleton.joint(.indexFingerTip)
            let col = (left.originFromAnchorTransform * tipJoint.anchorFromJointTransform).columns.3
            indexTips.append(SIMD3<Float>(col.x, col.y, col.z))
        }
        
        // Unused handComp removed
        
        for entity in entities {
            guard var component = entity.components[EmissiveButtonComponent.self] else { continue }
            
            var isCollidingWithIndex = false
            for tip in indexTips {
                if isPointInsideEntity(tip, entity: entity, padding: 0.005) {
                    isCollidingWithIndex = true
                    break
                }
            }
            
            if isCollidingWithIndex {

                if !component.isTouching {
                    component.isTouching = true
                    component.isOn.toggle()
                    component.startEmissiveValue = component.currentEmissiveValue
                    component.targetEmissiveValue = component.isOn ? 5.0 : 0.0
                    component.isAnimating = true
                    component.elapsedTime = 0
                    
                    print("👉 [NativeCollision] Index finger touched '\(entity.name)' -> Light: \(component.isOn ? "ON (5.0)" : "OFF (0.0)")")
                    
                    // Push button in 1cm
                    if component.originalPosition == nil {
                        component.originalPosition = entity.position
                    }
                    let restPos = component.originalPosition ?? entity.position
                    entity.position = restPos + SIMD3<Float>(0, 0, -0.01)
                }
            } else {
                if component.isTouching {
                    component.isTouching = false
                    if let restPos = component.originalPosition {
                        entity.position = restPos // Spring back out
                    }
                    print("✋ [NativeCollision] Index finger pulled away from '\(entity.name)' -> Button re-armed")
                }
            }

            
            // 2. Animate Emissive Light Transition
            if component.isAnimating {
                component.elapsedTime += context.deltaTime
                let progress = Float(min(1.0, component.elapsedTime / component.duration))
                let smoothProgress = progress * progress * (3.0 - 2.0 * progress)
                
                component.currentEmissiveValue = component.startEmissiveValue + (component.targetEmissiveValue - component.startEmissiveValue) * smoothProgress
                
                let targetsToUpdate = component.targetEntities.isEmpty ? findModelEntities(in: entity) : component.targetEntities
                for target in targetsToUpdate {
                    applyEmissiveTrigger(to: target, intensity: component.currentEmissiveValue)
                }
                
                if component.elapsedTime >= component.duration {
                    component.currentEmissiveValue = component.targetEmissiveValue
                    component.isAnimating = false
                }
            }
            
            entity.components.set(component)
        }
    }
    
    private func applyEmissiveTrigger(to entity: Entity, intensity: Float) {
        guard var modelComponent = entity.components[ModelComponent.self] else { return }
        
        var updatedMaterials = modelComponent.materials
        var modified = false
        
        for (i, mat) in updatedMaterials.enumerated() {
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
                
                for paramName in possibleNames {
                    do {
                        try shaderMat.setParameter(name: paramName, value: .float(intensity))
                        updatedMaterials[i] = shaderMat
                        modified = true
                    } catch {}
                }
            } else if var pbr = mat as? PhysicallyBasedMaterial {
                pbr.emissiveColor = .init(color: UIColor(red: 1.0, green: 0.7, blue: 0.1, alpha: 1.0))
                pbr.emissiveIntensity = intensity
                updatedMaterials[i] = pbr
                modified = true
            } else if var unlit = mat as? UnlitMaterial {
                unlit.color = .init(tint: UIColor(red: 1.0, green: 0.7, blue: 0.1, alpha: CGFloat(intensity)))
                updatedMaterials[i] = unlit
                modified = true
            } else if var simple = mat as? SimpleMaterial {
                simple.color = .init(tint: UIColor(red: 1.0, green: 0.7, blue: 0.1, alpha: CGFloat(intensity)))
                updatedMaterials[i] = simple
                modified = true
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
