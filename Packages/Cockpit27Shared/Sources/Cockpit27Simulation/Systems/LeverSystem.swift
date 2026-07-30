import RealityKit
import ARKit
import simd
import ILSHandTracking
import Cockpit27Core

@MainActor
public class LeverSystem: System {
    private static let query = EntityQuery(where: .has(LeverComponent.self))
    private static let handQuery = EntityQuery(where: .has(HandModelComponent.self))
    
    private let handTrackingService: HandTracking27ServiceProtocol?
    private let audioService: Audio27ServiceProtocol
    private let telemetryService: Cockpit27TelemetryProtocol
    
    // EMA Smoothing for stability
    private var smoothedLeftPalmPos: SIMD3<Float>?
    private var smoothedRightPalmPos: SIMD3<Float>?
    private var previousLeftPalmPos: SIMD3<Float>?
    private var previousRightPalmPos: SIMD3<Float>?
    
    private var smoothedLeftWristPos: SIMD3<Float>?
    private var smoothedRightWristPos: SIMD3<Float>?
    
    public required init(scene: RealityKit.Scene) {
        self.handTrackingService = DependencyContainer.shared.tryResolve(HandTracking27ServiceProtocol.self)
        self.audioService = DependencyContainer.shared.resolve(Audio27ServiceProtocol.self)
        self.telemetryService = DependencyContainer.shared.resolve(Cockpit27TelemetryProtocol.self)
    }
    
    private func evaluateGripState(skeleton: HandSkeleton?, component: inout LeverComponent, targetEntity: Entity, currentPalmWorldPos: SIMD3<Float>?) -> Bool {
        guard let skeleton = skeleton, let palm = currentPalmWorldPos else { return false }
        let thumbTipCol = skeleton.joint(.thumbTip).anchorFromJointTransform.columns.3
        let indexTipCol = skeleton.joint(.indexFingerTip).anchorFromJointTransform.columns.3
        let middleTipCol = skeleton.joint(.middleFingerTip).anchorFromJointTransform.columns.3
        let ringTipCol = skeleton.joint(.ringFingerTip).anchorFromJointTransform.columns.3
        
        let thumb = SIMD3<Float>(thumbTipCol.x, thumbTipCol.y, thumbTipCol.z)
        let middle = SIMD3<Float>(middleTipCol.x, middleTipCol.y, middleTipCol.z)
        let distanceThumbToMiddle = simd_distance(thumb, middle)
        
        // Check power fist curl
        let wristCol = skeleton.joint(.wrist).anchorFromJointTransform.columns.3
        let wrist = SIMD3<Float>(wristCol.x, wristCol.y, wristCol.z)
        let indexKnuckleCol = skeleton.joint(.indexFingerKnuckle).anchorFromJointTransform.columns.3
        let indexKnuckle = SIMD3<Float>(indexKnuckleCol.x, indexKnuckleCol.y, indexKnuckleCol.z)
        let middleKnuckleCol = skeleton.joint(.middleFingerKnuckle).anchorFromJointTransform.columns.3
        let middleKnuckle = SIMD3<Float>(middleKnuckleCol.x, middleKnuckleCol.y, middleKnuckleCol.z)
        let ringKnuckleCol = skeleton.joint(.ringFingerKnuckle).anchorFromJointTransform.columns.3
        let ringKnuckle = SIMD3<Float>(ringKnuckleCol.x, ringKnuckleCol.y, ringKnuckleCol.z)
        
        let index = SIMD3<Float>(indexTipCol.x, indexTipCol.y, indexTipCol.z)
        let ring = SIMD3<Float>(ringTipCol.x, ringTipCol.y, ringTipCol.z)
        
        let isIndexCurled = simd_distance(index, wrist) < simd_distance(indexKnuckle, wrist)
        let isMiddleCurled = simd_distance(middle, wrist) < simd_distance(middleKnuckle, wrist)
        let isRingCurled = simd_distance(ring, wrist) < simd_distance(ringKnuckle, wrist)
        
        let isPalmNearHandle = isPointInsideEntity(palm, entity: targetEntity, padding: 0.04)
        
        let distanceToIndex = simd_distance(thumb, index)
        let distanceToRing = simd_distance(thumb, ring)
        let isIndexTipNear = isPointInsideEntity(index, entity: targetEntity, padding: 0.01)
        
        if !component.isGrabbed {
            let isPinching = (distanceToIndex < 0.045) || (distanceThumbToMiddle < 0.045) || (distanceToRing < 0.045)
            let curledCount = (isIndexCurled ? 1 : 0) + (isMiddleCurled ? 1 : 0) + (isRingCurled ? 1 : 0)
            let isPowerGrip = (curledCount >= 2) && (distanceThumbToMiddle <= 0.06)
            return ((isPinching || isPowerGrip) && isPalmNearHandle) || isIndexTipNear
        } else {
            let handleWorldPos = targetEntity.visualBounds(relativeTo: nil).center
            let isTooFar = simd_distance(palm, handleWorldPos) > 0.45 // Release radius hysteresis
            let isPinching = (distanceToIndex < 0.10) || (distanceThumbToMiddle < 0.10) || (distanceToRing < 0.10)
            let isReleasingPower = (!isIndexCurled && !isMiddleCurled && !isRingCurled) || distanceThumbToMiddle > 0.08
            let isHolding = isPinching || !isReleasingPower
            return isHolding && !isTooFar
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
            let col = (anchor.originFromAnchorTransform * skeleton.joint(.middleFingerKnuckle).anchorFromJointTransform).columns.3
            leftPalmRaw = SIMD3<Float>(col.x, col.y, col.z)
            let wristCol = anchor.originFromAnchorTransform.columns.3
            leftWristRaw = SIMD3<Float>(wristCol.x, wristCol.y, wristCol.z)
        }
        if let anchor = rightHand, anchor.isTracked, let skeleton = anchor.handSkeleton {
            let col = (anchor.originFromAnchorTransform * skeleton.joint(.middleFingerKnuckle).anchorFromJointTransform).columns.3
            rightPalmRaw = SIMD3<Float>(col.x, col.y, col.z)
            let wristCol = anchor.originFromAnchorTransform.columns.3
            rightWristRaw = SIMD3<Float>(wristCol.x, wristCol.y, wristCol.z)
        }
        
        previousLeftPalmPos = smoothedLeftPalmPos
        previousRightPalmPos = smoothedRightPalmPos
        
        if let p = leftPalmRaw { smoothedLeftPalmPos = smoothedLeftPalmPos.map { $0 * 0.7 + p * 0.3 } ?? p } else { smoothedLeftPalmPos = nil; previousLeftPalmPos = nil }
        if let p = rightPalmRaw { smoothedRightPalmPos = smoothedRightPalmPos.map { $0 * 0.7 + p * 0.3 } ?? p } else { smoothedRightPalmPos = nil; previousRightPalmPos = nil }
        
        if let p = leftWristRaw { smoothedLeftWristPos = smoothedLeftWristPos.map { $0 * 0.7 + p * 0.3 } ?? p } else { smoothedLeftWristPos = nil }
        if let p = rightWristRaw { smoothedRightWristPos = smoothedRightWristPos.map { $0 * 0.7 + p * 0.3 } ?? p } else { smoothedRightWristPos = nil }
        
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
            let pivotBasePos = comp.pivotEntity?.position(relativeTo: nil) ?? entity.position(relativeTo: nil)
            if comp.initialWorldRotation == nil {
                comp.initialWorldRotation = comp.pivotEntity?.orientation(relativeTo: nil) ?? entity.orientation(relativeTo: nil)
            }
            let baseWorldRot = comp.initialWorldRotation!
            
            // Priority 1: Use handle mesh for bounds
            let meshEntity = comp.handleMeshEntity ?? entity
            let targetEntity = comp.handleMeshEntity ?? entity
            
            var isLeftNear = false
            var isRightNear = false
            
            if let lp = smoothedLeftPalmPos, isPointInsideEntity(lp, entity: targetEntity, padding: 0.02) { isLeftNear = true }
            if let rp = smoothedRightPalmPos, isPointInsideEntity(rp, entity: targetEntity, padding: 0.02) { isRightNear = true }
            
            guard isLeftNear || isRightNear || comp.isGrabbed else { continue }


            
            let activeSide: HandAnchor.Chirality
            if comp.isGrabbed {
                activeSide = (comp.activeChirality == 0) ? .left : .right
            } else {
                activeSide = isLeftNear ? .left : .right
            }
            let anchor = activeSide == .left ? leftHand : rightHand
            let skeleton = anchor?.handSkeleton
            
            let isHandBusy = activeSide == .left ? (handComp?.leftSnapPosition != nil) : (handComp?.rightSnapPosition != nil)
            let currentHandWorldPos = activeSide == .left ? smoothedLeftPalmPos : smoothedRightPalmPos
            let currentWristWorldPos = activeSide == .left ? smoothedLeftWristPos : smoothedRightWristPos
            let isGripping = evaluateGripState(skeleton: skeleton, component: &comp, targetEntity: targetEntity, currentPalmWorldPos: currentHandWorldPos)

            
            if !comp.isGrabbed {
                if !isHandBusy && isGripping, let handPos = currentHandWorldPos {
                    comp.isGrabbed = true
                    comp.previousHandWorldPosition = handPos
                    comp.activeChirality = activeSide == .left ? 0 : 1
                    
                    let wristPos = currentWristWorldPos ?? handPos
                    let currentQuat = simd_quatf(angle: comp.currentAngle, axis: comp.baseAxis)
                    let currentTiltedRot = baseWorldRot * currentQuat
                    
                    comp.initialGripOffset = currentTiltedRot.inverse.act(wristPos - pivotBasePos)
                    print("🎛️ [LeverSystem] Lever '\(entity.name)' GRABBED at Top Handle! Angle: \(comp.currentAngle)")
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
                    let activeChirality = comp.activeChirality
                    print("✋ [LeverSystem] Lever '\(entity.name)' RELEASED at Angle: \(comp.currentAngle)")
                    comp.isGrabbed = false
                    comp.activeChirality = -1
                    comp.initialGripOffset = nil
                    
                    if var hc = handComp {
                        if activeChirality == 0 { hc.leftSnapPosition = nil; hc.leftSnapOrientation = nil; hc.leftTargetGripPose = nil; hc.leftSnapBlend = 0.0 }
                        else if activeChirality == 1 { hc.rightSnapPosition = nil; hc.rightSnapOrientation = nil; hc.rightTargetGripPose = nil; hc.rightSnapBlend = 0.0 }
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
            
            // Calculate Hand Model Snap Socket at Top Handle
            if comp.isGrabbed, var hands = handComp {
                let isLeft = comp.activeChirality == 0
                
                var socketPos: SIMD3<Float>
                
                // Priority 2: Extract live bone world pos
                if let pivot = comp.pivotEntity, let model = pivot as? ModelEntity, !model.jointTransforms.isEmpty {
                    let handleJointIdx = min(comp.handleJointIndex, model.jointTransforms.count - 1)
                    let handleJointMat = model.jointTransforms[handleJointIdx].matrix
                    let modelWorldMat = model.transformMatrix(relativeTo: nil)
                    let handleWorldMat = modelWorldMat * handleJointMat
                    
                    socketPos = SIMD3<Float>(handleWorldMat.columns.3.x, handleWorldMat.columns.3.y, handleWorldMat.columns.3.z)
                } else {
                    let tiltedRot = baseWorldRot * quat
                    let socketOffset = comp.initialGripOffset ?? SIMD3<Float>(0.0, comp.leverRadius, 0.0)
                    socketPos = pivotBasePos + tiltedRot.act(socketOffset)
                }
                
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
            
            // Telemetry & Control Tag update
            if var controlTag = entity.components[CockpitControlTagComponent.self] {
                let norm = comp.maxAngle > 0 ? min(1.0, max(0.0, comp.currentAngle / comp.maxAngle)) : 0.0
                if abs(controlTag.normalizedValue - norm) > 0.01 {
                    controlTag.normalizedValue = norm
                    controlTag.isHandAttached = comp.isGrabbed
                    entity.components.set(controlTag)
                    telemetryService.reportControlStateChanged(controlID: comp.controlID, normalizedValue: norm, stateIndex: nil)
                }
            }
        }
    }
}
