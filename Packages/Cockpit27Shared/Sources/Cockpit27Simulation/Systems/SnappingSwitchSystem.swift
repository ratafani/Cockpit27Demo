import RealityKit
import ARKit
import simd
import ILSHandTracking

@MainActor
public class SnappingSwitchSystem: System {
    private static let query = EntityQuery(where: .has(SnappingSwitchComponent.self))
    private static let panelQuery = EntityQuery(where: .has(PanelVolumeComponent.self))
    
    private var smoothedLeftTipPos: SIMD3<Float>?
    private var smoothedRightTipPos: SIMD3<Float>?
    
    private var leftHandTargetID: Entity.ID?
    private var rightHandTargetID: Entity.ID?
    
    public required init(scene: RealityKit.Scene) {}
    
    private func checkActive(_ entity: Entity) -> Bool {
        var current: Entity? = entity.parent
        while let p = current {
            if let panel = p.components[PanelVolumeComponent.self] { return panel.isActive }
            current = p.parent
        }
        return true
    }
    
    private func getLocalPos(_ worldPos: SIMD3<Float>, entity: Entity) -> SIMD3<Float> {
        let parentTransform = entity.parent?.transformMatrix(relativeTo: nil) ?? matrix_identity_float4x4
        let inv = simd_inverse(parentTransform)
        let local = simd_mul(inv, SIMD4<Float>(worldPos, 1.0))
        return SIMD3<Float>(local.x, local.y, local.z) / local.w
    }
    
    public func update(context: SceneUpdateContext) {
        let leftHand = CockpitHandTracking.currentService?.latestLeftHand
        let rightHand = CockpitHandTracking.currentService?.latestRightHand
        
        var leftTipRaw: SIMD3<Float>? = nil
        var rightTipRaw: SIMD3<Float>? = nil
        
        if let anchor = leftHand, anchor.isTracked, let skeleton = anchor.handSkeleton {
            let col = (anchor.originFromAnchorTransform * skeleton.joint(.indexFingerTip).anchorFromJointTransform).columns.3
            leftTipRaw = SIMD3<Float>(col.x, col.y, col.z)
        }
        if let anchor = rightHand, anchor.isTracked, let skeleton = anchor.handSkeleton {
            let col = (anchor.originFromAnchorTransform * skeleton.joint(.indexFingerTip).anchorFromJointTransform).columns.3
            rightTipRaw = SIMD3<Float>(col.x, col.y, col.z)
        }
        
        if let p = leftTipRaw { smoothedLeftTipPos = smoothedLeftTipPos.map { $0 * 0.7 + p * 0.3 } ?? p } else { smoothedLeftTipPos = nil }
        if let p = rightTipRaw { smoothedRightTipPos = smoothedRightTipPos.map { $0 * 0.7 + p * 0.3 } ?? p } else { smoothedRightTipPos = nil }
        
        for entity in context.scene.performQuery(Self.query) {
            var comp = entity.components[SnappingSwitchComponent.self]!
            if !checkActive(entity) { continue }
            
            var targetWorldPos: SIMD3<Float>? = nil
            let box = entity.visualBounds(relativeTo: nil)
            let expandBox = BoundingBox(min: box.min - 0.05, max: box.max + 0.05)
            
            if leftHandTargetID == nil, let lPos = smoothedLeftTipPos, box.contains(lPos) { leftHandTargetID = entity.id }
            else if rightHandTargetID == nil, let rPos = smoothedRightTipPos, box.contains(rPos) { rightHandTargetID = entity.id }
            
            if leftHandTargetID == entity.id {
                if let lPos = smoothedLeftTipPos, expandBox.contains(lPos) { targetWorldPos = lPos } else { leftHandTargetID = nil }
            } else if rightHandTargetID == entity.id {
                if let rPos = smoothedRightTipPos, expandBox.contains(rPos) { targetWorldPos = rPos } else { rightHandTargetID = nil }
            }
            
            if let worldPos = targetWorldPos {
                let handLocal = getLocalPos(worldPos, entity: entity)
                let thetaHand = atan2(handLocal.y - entity.position.y, handLocal.x - entity.position.x)
                for (i, state) in comp.states.enumerated() {
                    let normDiff = min(abs(thetaHand - state), Float.pi * 2 - abs(thetaHand - state))
                    if normDiff < comp.hysteresisThreshold {
                        if comp.currentStateIndex != i {
                            comp.currentStateIndex = i
                            entity.transform.rotation = simd_quatf(angle: state, axis: comp.localRotationAxis)
                        }
                        break
                    }
                }
            }
            entity.components.set(comp)
        }
    }
}
