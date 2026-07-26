import RealityKit
import ARKit
import simd
import ILSHandTracking

@MainActor
public class LeverSystem: System {
    private static let query = EntityQuery(where: .has(LeverComponent.self))
    private static let handQuery = EntityQuery(where: .has(HandModelComponent.self))
    
    // EMA Smoothing for stability
    private var smoothedLeftPalmPos: SIMD3<Float>?
    private var smoothedRightPalmPos: SIMD3<Float>?
    private var previousLeftPalmPos: SIMD3<Float>?
    private var previousRightPalmPos: SIMD3<Float>?
    
    private var smoothedLeftWristPos: SIMD3<Float>?
    private var smoothedRightWristPos: SIMD3<Float>?
    
    public required init(scene: RealityKit.Scene) {}
    
    private func evaluateGripState(skeleton: HandSkeleton?, component: inout LeverComponent) -> Bool {
        guard let skeleton = skeleton else { return false }
        let thumbTipCol = skeleton.joint(.thumbTip).anchorFromJointTransform.columns.3
        let indexTipCol = skeleton.joint(.indexFingerTip).anchorFromJointTransform.columns.3
        let middleTipCol = skeleton.joint(.middleFingerTip).anchorFromJointTransform.columns.3
        let ringTipCol = skeleton.joint(.ringFingerTip).anchorFromJointTransform.columns.3
        let littleTipCol = skeleton.joint(.littleFingerTip).anchorFromJointTransform.columns.3
        
        let thumb = SIMD3<Float>(thumbTipCol.x, thumbTipCol.y, thumbTipCol.z)
        let index = SIMD3<Float>(indexTipCol.x, indexTipCol.y, indexTipCol.z)
        let middle = SIMD3<Float>(middleTipCol.x, middleTipCol.y, middleTipCol.z)
        let ring = SIMD3<Float>(ringTipCol.x, ringTipCol.y, ringTipCol.z)
        let little = SIMD3<Float>(littleTipCol.x, littleTipCol.y, littleTipCol.z)
        
        let distanceToIndex = simd_distance(thumb, index)
        let distanceToMiddle = simd_distance(thumb, middle)
        let distanceToRing = simd_distance(thumb, ring)
        let distanceToLittle = simd_distance(thumb, little)
        
        // Also check power fist curl
        let wristCol = skeleton.joint(.wrist).anchorFromJointTransform.columns.3
        let wrist = SIMD3<Float>(wristCol.x, wristCol.y, wristCol.z)
        let indexKnuckleCol = skeleton.joint(.indexFingerKnuckle).anchorFromJointTransform.columns.3
        let indexKnuckle = SIMD3<Float>(indexKnuckleCol.x, indexKnuckleCol.y, indexKnuckleCol.z)
        let isIndexCurled = simd_distance(index, wrist) < simd_distance(indexKnuckle, wrist)
        
        if !component.isGrabbed {
            return (distanceToIndex < 0.045) || (distanceToMiddle < 0.045) || (distanceToRing < 0.045) || isIndexCurled
        } else {
            let isReleasing = (distanceToIndex > 0.075) && (distanceToMiddle > 0.075) && (distanceToRing > 0.075) && !isIndexCurled
            return !isReleasing
        }
    }
    
    public func update(context: SceneUpdateContext) {
        let leftHand = CockpitHandTracking.currentService?.latestLeftHand
        let rightHand = CockpitHandTracking.currentService?.latestRightHand
        
        // ── 1. Compute smoothed palm and wrist positions ────────────────────
        var leftPalmRaw: SIMD3<Float>? = nil
        var rightPalmRaw: SIMD3<Float>? = nil
        var leftWristRaw: SIMD3<Float>? = nil
        var rightWristRaw: SIMD3<Float>? = nil
        
        if let anchor = leftHand, anchor.isTracked, let skeleton = anchor.handSkeleton {
            let palmCol = (anchor.originFromAnchorTransform * skeleton.joint(.middleFingerKnuckle).anchorFromJointTransform).columns.3
            leftPalmRaw = SIMD3<Float>(palmCol.x, palmCol.y, palmCol.z)
            let wristCol = anchor.originFromAnchorTransform.columns.3
            leftWristRaw = SIMD3<Float>(wristCol.x, wristCol.y, wristCol.z)
        }
        if let anchor = rightHand, anchor.isTracked, let skeleton = anchor.handSkeleton {
            let palmCol = (anchor.originFromAnchorTransform * skeleton.joint(.middleFingerKnuckle).anchorFromJointTransform).columns.3
            rightPalmRaw = SIMD3<Float>(palmCol.x, palmCol.y, palmCol.z)
            let wristCol = anchor.originFromAnchorTransform.columns.3
            rightWristRaw = SIMD3<Float>(wristCol.x, wristCol.y, wristCol.z)
        }
        
        previousLeftPalmPos = smoothedLeftPalmPos
        previousRightPalmPos = smoothedRightPalmPos
        
        if let p = leftPalmRaw { smoothedLeftPalmPos = smoothedLeftPalmPos.map { $0 * 0.8 + p * 0.2 } ?? p } else { smoothedLeftPalmPos = nil; previousLeftPalmPos = nil }
        if let p = rightPalmRaw { smoothedRightPalmPos = smoothedRightPalmPos.map { $0 * 0.8 + p * 0.2 } ?? p } else { smoothedRightPalmPos = nil; previousRightPalmPos = nil }
        if let p = leftWristRaw { smoothedLeftWristPos = smoothedLeftWristPos.map { $0 * 0.8 + p * 0.2 } ?? p } else { smoothedLeftWristPos = nil }
        if let p = rightWristRaw { smoothedRightWristPos = smoothedRightWristPos.map { $0 * 0.8 + p * 0.2 } ?? p } else { smoothedRightWristPos = nil }
        
        // ── 2. Find HandModelComponent ─────────────────────────────────────
        var handComp: HandModelComponent?
        var handEntity: Entity?
        for entity in context.scene.performQuery(Self.handQuery) {
            handComp = entity.components[HandModelComponent.self]
            handEntity = entity
            break
        }
        
        // ── 3. Process each lever entity ────────────────────────────────────
        for entity in context.scene.performQuery(Self.query) {
            var comp = entity.components[LeverComponent.self]!
            let worldPos = comp.pivotEntity?.position(relativeTo: nil) ?? entity.position(relativeTo: nil)
            
            let triggerRadius: Float = 0.12
            
            var isLeftNear = false
            var isRightNear = false
            
            if let lp = smoothedLeftPalmPos, simd_distance(lp, worldPos) < triggerRadius { isLeftNear = true }
            if let rp = smoothedRightPalmPos, simd_distance(rp, worldPos) < triggerRadius { isRightNear = true }
            
            guard isLeftNear || isRightNear || comp.isGrabbed else { continue }
            
            let activeSide: HandAnchor.Chirality = isLeftNear ? .left : .right
            let anchor = activeSide == .left ? leftHand : rightHand
            let skeleton = anchor?.handSkeleton
            
            let isHandBusy = activeSide == .left ? (handComp?.leftSnapPosition != nil) : (handComp?.rightSnapPosition != nil)
            let currentHandWorldPos = activeSide == .left ? smoothedLeftPalmPos : smoothedRightPalmPos
            let currentWristWorldPos = activeSide == .left ? smoothedLeftWristPos : smoothedRightWristPos
            let isGripping = evaluateGripState(skeleton: skeleton, component: &comp)
            
            if !comp.isGrabbed {
                if !isHandBusy && isGripping, let handPos = currentHandWorldPos {
                    comp.isGrabbed = true
                    comp.previousHandWorldPosition = handPos
                    comp.activeChirality = activeSide == .left ? 0 : 1
                    
                    let leverWorldPos = worldPos
                    let leverWorldRot = entity.orientation(relativeTo: nil)
                    let wristPos = currentWristWorldPos ?? handPos
                    comp.initialGripOffset = leverWorldRot.inverse.act(wristPos - leverWorldPos)
                    print("🎛️ [LeverSystem] Lever '\(entity.name)' GRABBED by \(activeSide == .left ? "Left" : "Right") Hand! Angle: \(comp.currentAngle)")
                }
            } else {
                if isGripping, let handPos = currentHandWorldPos {
                    let worldDelta = handPos - comp.previousHandWorldPosition
                    
                    // Moving hand forward (-Z) or up (+Y) advances the lever angle
                    let linearMovement = -worldDelta.z + worldDelta.y * 0.5
                    let deltaTheta = (linearMovement / comp.leverRadius) * comp.sensitivity
                    var targetAngle = comp.currentAngle + deltaTheta
                    
                    // Soft detent magnetic pull
                    for detent in comp.detents {
                        if abs(targetAngle - detent) < comp.detentTolerance * 0.5 {
                            targetAngle = detent
                            break
                        }
                    }
                    
                    comp.currentAngle = max(0, min(targetAngle, comp.maxAngle))
                    comp.previousHandWorldPosition = handPos
                    print("🎛️ [LeverSystem] Lever '\(entity.name)' Moving -> Angle: \(comp.currentAngle)")
                } else {
                    // Release & snap to nearest detent if within tolerance
                    for detent in comp.detents {
                        if abs(comp.currentAngle - detent) < comp.detentTolerance {
                            comp.currentAngle = detent
                            break
                        }
                    }
                    print("✋ [LeverSystem] Lever '\(entity.name)' RELEASED at Angle: \(comp.currentAngle)")
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
            
            // Apply Lever Rotation
            let quat = simd_quatf(angle: comp.currentAngle, axis: comp.baseAxis)
            if let pivot = comp.pivotEntity {
                if let model = pivot as? ModelEntity, !model.jointTransforms.isEmpty {
                    let jointIdx = min(comp.boneIndex, model.jointTransforms.count - 1)
                    if comp.initialBoneRotation == nil {
                        comp.initialBoneRotation = model.jointTransforms[jointIdx].rotation
                    }
                    let initial = comp.initialBoneRotation!
                    var transforms = model.jointTransforms
                    transforms[jointIdx].rotation = quat * initial
                    model.jointTransforms = transforms
                } else {
                    if comp.initialEntityRotation == nil {
                        comp.initialEntityRotation = pivot.transform.rotation
                    }
                    let initial = comp.initialEntityRotation!
                    pivot.transform.rotation = quat * initial
                }
            } else {
                if comp.initialEntityRotation == nil {
                    comp.initialEntityRotation = entity.transform.rotation
                }
                let initial = comp.initialEntityRotation!
                entity.transform.rotation = quat * initial
            }
            
            // Calculate Hand Model Snap Socket
            if comp.isGrabbed, var hands = handComp {
                let isLeft = comp.activeChirality == 0
                let leverWorldPos = entity.position(relativeTo: nil)
                let leverWorldRot = entity.orientation(relativeTo: nil)
                let socketOffset = comp.initialGripOffset ?? SIMD3<Float>(0.0, 0.12, 0.0)
                let socketPos = leverWorldPos + leverWorldRot.act(socketOffset)
                
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
