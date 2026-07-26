import RealityKit
import ARKit
import simd
import ILSHandTracking

@MainActor
public class RotationalKnobSystem: System {
    private static let query = EntityQuery(where: .has(RotationalKnobComponent.self))
    private static let panelQuery = EntityQuery(where: .has(PanelVolumeComponent.self))
    private static let handQuery = EntityQuery(where: .has(HandModelComponent.self))
    
    private var smoothedLeftTipPos: SIMD3<Float>?
    private var smoothedRightTipPos: SIMD3<Float>?
    private var previousLeftTipPos: SIMD3<Float>?
    private var previousRightTipPos: SIMD3<Float>?
    
    private var smoothedLeftWristPos: SIMD3<Float>?
    private var smoothedRightWristPos: SIMD3<Float>?
    
    public required init(scene: RealityKit.Scene) {}
    
    private func checkActive(_ entity: Entity) -> Bool {
        var current: Entity? = entity.parent
        while let p = current {
            if let panel = p.components[PanelVolumeComponent.self] { return panel.isActive }
            current = p.parent
        }
        return true
    }
    
    private func evaluatePinchState(skeleton: HandSkeleton?, component: inout RotationalKnobComponent) -> Bool {
        guard let skeleton = skeleton else { return false }
        let thumbTipCol = skeleton.joint(.thumbTip).anchorFromJointTransform.columns.3
        let indexTipCol = skeleton.joint(.indexFingerTip).anchorFromJointTransform.columns.3
        let middleTipCol = skeleton.joint(.middleFingerTip).anchorFromJointTransform.columns.3
        
        let thumb = SIMD3<Float>(thumbTipCol.x, thumbTipCol.y, thumbTipCol.z)
        let index = SIMD3<Float>(indexTipCol.x, indexTipCol.y, indexTipCol.z)
        let middle = SIMD3<Float>(middleTipCol.x, middleTipCol.y, middleTipCol.z)
        
        let distanceToIndex = simd_distance(thumb, index)
        let distanceToMiddle = simd_distance(thumb, middle)
        
        if !component.isGrabbed {
            return (distanceToIndex < 0.045) || (distanceToMiddle < 0.045)
        } else {
            let isReleasing = (distanceToIndex > 0.075) && (distanceToMiddle > 0.075)
            return !isReleasing
        }
    }
    
    public func update(context: SceneUpdateContext) {
        let leftHand = CockpitHandTracking.currentService?.latestLeftHand
        let rightHand = CockpitHandTracking.currentService?.latestRightHand
        
        var leftTipRaw: SIMD3<Float>? = nil
        var rightTipRaw: SIMD3<Float>? = nil
        var leftWristRaw: SIMD3<Float>? = nil
        var rightWristRaw: SIMD3<Float>? = nil
        
        if let anchor = leftHand, anchor.isTracked, let skeleton = anchor.handSkeleton {
            let col = (anchor.originFromAnchorTransform * skeleton.joint(.indexFingerTip).anchorFromJointTransform).columns.3
            leftTipRaw = SIMD3<Float>(col.x, col.y, col.z)
            let wristCol = anchor.originFromAnchorTransform.columns.3
            leftWristRaw = SIMD3<Float>(wristCol.x, wristCol.y, wristCol.z)
        }
        if let anchor = rightHand, anchor.isTracked, let skeleton = anchor.handSkeleton {
            let col = (anchor.originFromAnchorTransform * skeleton.joint(.indexFingerTip).anchorFromJointTransform).columns.3
            rightTipRaw = SIMD3<Float>(col.x, col.y, col.z)
            let wristCol = anchor.originFromAnchorTransform.columns.3
            rightWristRaw = SIMD3<Float>(wristCol.x, wristCol.y, wristCol.z)
        }
        
        previousLeftTipPos = smoothedLeftTipPos
        previousRightTipPos = smoothedRightTipPos
        
        if let p = leftTipRaw { smoothedLeftTipPos = smoothedLeftTipPos.map { $0 * 0.7 + p * 0.3 } ?? p } else { smoothedLeftTipPos = nil; previousLeftTipPos = nil }
        if let p = rightTipRaw { smoothedRightTipPos = smoothedRightTipPos.map { $0 * 0.7 + p * 0.3 } ?? p } else { smoothedRightTipPos = nil; previousRightTipPos = nil }
        if let p = leftWristRaw { smoothedLeftWristPos = smoothedLeftWristPos.map { $0 * 0.7 + p * 0.3 } ?? p } else { smoothedLeftWristPos = nil }
        if let p = rightWristRaw { smoothedRightWristPos = smoothedRightWristPos.map { $0 * 0.7 + p * 0.3 } ?? p } else { smoothedRightWristPos = nil }
        
        var handComp: HandModelComponent?
        var handEntity: Entity?
        for entity in context.scene.performQuery(Self.handQuery) {
            handComp = entity.components[HandModelComponent.self]
            handEntity = entity
            break
        }
        
        for entity in context.scene.performQuery(Self.query) {
            var comp = entity.components[RotationalKnobComponent.self]!
            if !checkActive(entity) { continue }
            
            let worldPos = entity.position(relativeTo: nil)
            let triggerRadius: Float = 0.08
            
            var isLeftNear = false
            var isRightNear = false
            if let lp = smoothedLeftTipPos, simd_distance(lp, worldPos) < triggerRadius { isLeftNear = true }
            if let rp = smoothedRightTipPos, simd_distance(rp, worldPos) < triggerRadius { isRightNear = true }
            
            guard isLeftNear || isRightNear || comp.isGrabbed else { continue }
            
            let activeSide: HandAnchor.Chirality = isLeftNear ? .left : .right
            let anchor = activeSide == .left ? leftHand : rightHand
            let skeleton = anchor?.handSkeleton
            
            let isHandBusy = activeSide == .left ? (handComp?.leftSnapPosition != nil) : (handComp?.rightSnapPosition != nil)
            let currentTipWorldPos = activeSide == .left ? smoothedLeftTipPos : smoothedRightTipPos
            let currentWristWorldPos = activeSide == .left ? smoothedLeftWristPos : smoothedRightWristPos
            let isPinching = evaluatePinchState(skeleton: skeleton, component: &comp)
            
            if !comp.isGrabbed {
                if !isHandBusy && isPinching, let tipPos = currentTipWorldPos {
                    comp.isGrabbed = true
                    comp.previousHandWorldPosition = tipPos
                    comp.activeChirality = activeSide == .left ? 0 : 1
                    
                    let knobWorldPos = entity.position(relativeTo: nil)
                    let knobWorldRot = entity.orientation(relativeTo: nil)
                    let wristPos = currentWristWorldPos ?? tipPos
                    comp.initialGripOffset = knobWorldRot.inverse.act(wristPos - knobWorldPos)
                    print("🔘 [RotationalKnobSystem] Knob '\(entity.name)' PINCHED by \(activeSide == .left ? "Left" : "Right") Hand! Angle: \(comp.currentAngle)")
                }
            } else {
                if isPinching, let tipPos = currentTipWorldPos {
                    let parentEntity = entity.parent ?? entity
                    let localDelta = parentEntity.convert(position: tipPos, from: nil) - parentEntity.convert(position: comp.previousHandWorldPosition, from: nil)
                    
                    comp.currentAngle += localDelta.x * comp.sensitivity
                    entity.transform.rotation = simd_quatf(angle: comp.currentAngle, axis: comp.localRotationAxis)
                    comp.previousHandWorldPosition = tipPos
                    print("🔘 [RotationalKnobSystem] Knob '\(entity.name)' Rotating -> Angle: \(comp.currentAngle)")
                } else {
                    print("✋ [RotationalKnobSystem] Knob '\(entity.name)' RELEASED")
                    comp.isGrabbed = false
                    comp.activeChirality = -1
                    comp.initialGripOffset = nil
                    
                    if var hc = handComp {
                        if activeSide == .left { hc.leftSnapPosition = nil; hc.leftSnapOrientation = nil }
                        else { hc.rightSnapPosition = nil; hc.rightSnapOrientation = nil }
                        handEntity?.components.set(hc)
                        handComp = hc
                    }
                }
            }
            
            if comp.isGrabbed, var hands = handComp {
                let isLeft = comp.activeChirality == 0
                let knobWorldPos = entity.position(relativeTo: nil)
                let knobWorldRot = entity.orientation(relativeTo: nil)
                let socketOffset = comp.initialGripOffset ?? SIMD3<Float>(0.0, 0.05, 0.0)
                let socketPos = knobWorldPos + knobWorldRot.act(socketOffset)
                
                if isLeft {
                    hands.leftSnapPosition = socketPos
                    hands.leftSnapOrientation = nil
                } else {
                    hands.rightSnapPosition = socketPos
                    hands.rightSnapOrientation = nil
                }
                handEntity?.components.set(hands)
                handComp = hands
            }
            
            entity.components.set(comp)
        }
    }
}
