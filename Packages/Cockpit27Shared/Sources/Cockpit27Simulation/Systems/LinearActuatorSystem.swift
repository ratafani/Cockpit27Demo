import RealityKit
import ARKit
import simd
import ILSHandTracking

@MainActor
public class LinearActuatorSystem: System {
    private static let query = EntityQuery(where: .has(LinearActuatorComponent.self))
    private static let panelQuery = EntityQuery(where: .has(PanelVolumeComponent.self))
    
    // EMA Smoothing for index tip
    private var smoothedLeftTipPos: SIMD3<Float>?
    private var smoothedRightTipPos: SIMD3<Float>?
    
    // Lock targets
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
        
        // ── Panel Broadphase ──────────────────────────────────────
        for entity in context.scene.performQuery(Self.panelQuery) {
            var comp = entity.components[PanelVolumeComponent.self]!
            comp.isActive = false
            let box = comp.boundingBox
            let inv = simd_inverse(entity.transformMatrix(relativeTo: nil))
            func inBox(_ w: SIMD3<Float>?) -> Bool {
                guard let w = w else { return false }
                let l = simd_mul(inv, SIMD4<Float>(w, 1.0))
                return box.contains(SIMD3<Float>(l.x, l.y, l.z) / l.w)
            }
            if inBox(smoothedLeftTipPos) || inBox(smoothedRightTipPos) { comp.isActive = true }
            entity.components.set(comp)
        }
        
        // ── Linear Actuator Solver ─────────────────────────
        for entity in context.scene.performQuery(Self.query) {
            var comp = entity.components[LinearActuatorComponent.self]!
            if !checkActive(entity) { continue }
            
            var targetWorldPos: SIMD3<Float>? = nil
            
            var isLeftTouching = false
            var isRightTouching = false
            
            if let lPos = smoothedLeftTipPos, isPointInsideEntity(lPos, entity: entity, padding: 0.008) {
                isLeftTouching = true
            }
            if let rPos = smoothedRightTipPos, isPointInsideEntity(rPos, entity: entity, padding: 0.008) {
                isRightTouching = true
            }

            
            if leftHandTargetID == nil && isLeftTouching { leftHandTargetID = entity.id }
            else if rightHandTargetID == nil && isRightTouching { rightHandTargetID = entity.id }
            
            if leftHandTargetID == entity.id {
                if isLeftTouching, let lPos = smoothedLeftTipPos { targetWorldPos = lPos } else { leftHandTargetID = nil }
            } else if rightHandTargetID == entity.id {
                if isRightTouching, let rPos = smoothedRightTipPos { targetWorldPos = rPos } else { rightHandTargetID = nil }
            }
            
            if let worldPos = targetWorldPos {
                let handLocal = getLocalPos(worldPos, entity: entity)
                let travel = max(0, min(simd_dot(handLocal - comp.restPosition, comp.localAxis), comp.maxTravel))
                entity.position = comp.restPosition + (comp.localAxis * travel)
                comp.isPressed = (travel > comp.maxTravel * 0.9)
            } else {
                comp.isPressed = false
                entity.position = simd_mix(entity.position, comp.restPosition, SIMD3<Float>(repeating: 0.2))
            }
            entity.components.set(comp)
        }

    }
}
