import RealityKit
import ARKit
import simd
import ILSHandTracking

@MainActor
public class RotationalKnobSystem: System {
    private static let query = EntityQuery(where: .has(RotationalKnobComponent.self))
    private static let panelQuery = EntityQuery(where: .has(PanelVolumeComponent.self))
    
    private var smoothedLeftTipPos: SIMD3<Float>?
    private var smoothedRightTipPos: SIMD3<Float>?
    private var previousLeftTipPos: SIMD3<Float>?
    private var previousRightTipPos: SIMD3<Float>?
    
    public required init(scene: RealityKit.Scene) {}
    
    private func checkActive(_ entity: Entity) -> Bool {
        var current: Entity? = entity.parent
        while let p = current {
            if let panel = p.components[PanelVolumeComponent.self] { return panel.isActive }
            current = p.parent
        }
        return true
    }
    
    private func isFingerCurled(skeleton: HandSkeleton,
                                tip: HandSkeleton.JointName,
                                knuckle: HandSkeleton.JointName) -> Bool {
        let tipCol    = skeleton.joint(tip).anchorFromJointTransform.columns.3
        let knuckleCol = skeleton.joint(knuckle).anchorFromJointTransform.columns.3
        let wristCol  = skeleton.joint(.wrist).anchorFromJointTransform.columns.3
        let tipDist     = simd_distance(SIMD3<Float>(tipCol.x,    tipCol.y,    tipCol.z),
                                        SIMD3<Float>(wristCol.x,  wristCol.y,  wristCol.z))
        let knuckleDist = simd_distance(SIMD3<Float>(knuckleCol.x, knuckleCol.y, knuckleCol.z),
                                        SIMD3<Float>(wristCol.x,   wristCol.y,   wristCol.z))
        return tipDist < knuckleDist
    }
    
    private func isHandCurled(skeleton: HandSkeleton?) -> Bool {
        guard let skeleton = skeleton else { return false }
        let curledCount = [
            isFingerCurled(skeleton: skeleton, tip: .indexFingerTip,  knuckle: .indexFingerKnuckle),
            isFingerCurled(skeleton: skeleton, tip: .middleFingerTip, knuckle: .middleFingerKnuckle),
            isFingerCurled(skeleton: skeleton, tip: .ringFingerTip,   knuckle: .ringFingerKnuckle),
            isFingerCurled(skeleton: skeleton, tip: .littleFingerTip, knuckle: .littleFingerKnuckle)
        ].filter { $0 }.count
        return curledCount >= 3
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
        
        previousLeftTipPos = smoothedLeftTipPos
        previousRightTipPos = smoothedRightTipPos
        
        if let p = leftTipRaw { smoothedLeftTipPos = smoothedLeftTipPos.map { $0 * 0.7 + p * 0.3 } ?? p } else { smoothedLeftTipPos = nil; previousLeftTipPos = nil }
        if let p = rightTipRaw { smoothedRightTipPos = smoothedRightTipPos.map { $0 * 0.7 + p * 0.3 } ?? p } else { smoothedRightTipPos = nil; previousRightTipPos = nil }
        
        let isLeftCurled = isHandCurled(skeleton: leftHand?.handSkeleton)
        let isRightCurled = isHandCurled(skeleton: rightHand?.handSkeleton)
        
        for entity in context.scene.performQuery(Self.query) {
            var comp = entity.components[RotationalKnobComponent.self]!
            if !checkActive(entity) { continue }
            
            let box = entity.visualBounds(relativeTo: nil)
            let expandBox = BoundingBox(min: box.min - 0.02, max: box.max + 0.02)
            
            var activeHandPos: SIMD3<Float>? = nil
            var activePreviousPos: SIMD3<Float>? = nil
            var activeCurled = false
            
            if let lPos = smoothedLeftTipPos, expandBox.contains(lPos) {
                activeHandPos = lPos; activePreviousPos = previousLeftTipPos; activeCurled = isLeftCurled
            } else if let rPos = smoothedRightTipPos, expandBox.contains(rPos) {
                activeHandPos = rPos; activePreviousPos = previousRightTipPos; activeCurled = isRightCurled
            }
            
            if comp.isGrabbed { if !activeCurled { comp.isGrabbed = false } }
            else { if activeHandPos != nil && activeCurled { comp.isGrabbed = true } }
            
            if (comp.isGrabbed || activeHandPos != nil),
               let cur = activeHandPos, let prev = activePreviousPos {
                let parentEntity = entity.parent ?? entity
                let localDelta = parentEntity.convert(position: cur, from: nil) - parentEntity.convert(position: prev, from: nil)
                comp.currentAngle += localDelta.x * comp.sensitivity
                entity.transform.rotation = simd_quatf(angle: comp.currentAngle, axis: comp.localRotationAxis)
            }
            entity.components.set(comp)
        }
    }
}
