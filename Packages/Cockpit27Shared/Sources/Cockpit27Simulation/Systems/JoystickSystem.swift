import RealityKit
import ARKit
import simd
import ILSHandTracking

@MainActor
public class JoystickSystem: System {
    private static let query = EntityQuery(where: .has(JoystickComponent.self))
    private static let handQuery = EntityQuery(where: .has(HandModelComponent.self))
    
    // EMA Smoothing for stability
    private var smoothedLeftPalmPos: SIMD3<Float>?
    private var smoothedRightPalmPos: SIMD3<Float>?
    private var previousLeftPalmPos: SIMD3<Float>?
    private var previousRightPalmPos: SIMD3<Float>?
    
    private var smoothedLeftWristPos: SIMD3<Float>?
    private var smoothedRightWristPos: SIMD3<Float>?
    
    public required init(scene: RealityKit.Scene) {}
    
    // Power Grip Biomechanics
    private func evaluateGripState(skeleton: HandSkeleton?, component: inout JoystickComponent) -> Bool {
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
        
        if !component.isLocked {
            return (distanceToIndex < 0.045) || (distanceToMiddle < 0.045) || (distanceToRing < 0.045) || (distanceToLittle < 0.045)
        } else {
            let isReleasing = (distanceToIndex > 0.07) && (distanceToMiddle > 0.07) && (distanceToRing > 0.07) && (distanceToLittle > 0.07)
            return !isReleasing 
        }
    }
    
    public func update(context: SceneUpdateContext) {
        let leftHand = CockpitHandTracking.currentService?.latestLeftHand
        let rightHand = CockpitHandTracking.currentService?.latestRightHand
        
        // ── 1. Compute smoothed palm positions ──────────────────────────────
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
        
        // ── 2. Find the HandModelComponent to get glove references ──────────
        var handComp: HandModelComponent?
        var handEntity: Entity?
        for entity in context.scene.performQuery(Self.handQuery) {
            handComp = entity.components[HandModelComponent.self]
            handEntity = entity
            break
        }
        
        // ── 3. Process each joystick entity ─────────────────────────────────
        for entity in context.scene.performQuery(Self.query) {
            var comp = entity.components[JoystickComponent.self]!
            let worldPos = entity.position(relativeTo: nil)
            
            // Distance check for hand proximity
            let triggerRadius: Float = 0.25
            
            var isLeftNear = false
            var isRightNear = false
            
            if let lp = smoothedLeftPalmPos, simd_distance(lp, worldPos) < triggerRadius { isLeftNear = true }
            if let rp = smoothedRightPalmPos, simd_distance(rp, worldPos) < triggerRadius { isRightNear = true }
            
            comp.isHandInsideCollider = isLeftNear || isRightNear
            
            // Determine which hand is active
            let activeSide: HandAnchor.Chirality = isLeftNear ? .left : .right
            let anchor = activeSide == .left ? leftHand : rightHand
            let skeleton = anchor?.handSkeleton
            
            let currentHandWorldPos = activeSide == .left ? smoothedLeftPalmPos : smoothedRightPalmPos
            let currentWristWorldPos = activeSide == .left ? smoothedLeftWristPos : smoothedRightWristPos
            let isGripping = evaluateGripState(skeleton: skeleton, component: &comp)
            
            // ── GRAB / LOCK STATE MACHINE ───────────────────────────────────
            if !comp.isLocked {
                if comp.isHandInsideCollider && isGripping, let handPos = currentHandWorldPos {
                    comp.isLocked = true
                    comp.previousHandWorldPosition = handPos
                    comp.activeChirality = activeSide == .left ? 0 : 1
                    
                    // Capture exactly where the user grabbed the stick in its tilted local space
                    let stickWorldPos = entity.position(relativeTo: nil)
                    let stickWorldRot = entity.orientation(relativeTo: nil)
                    
                    // Calculate the current tilt (since they might grab it while it's already tilted slightly)
                    let pitchQ = simd_quatf(angle: comp.currentPitch, axis: [1, 0, 0])
                    let rollQ = simd_quatf(angle: -comp.currentRoll, axis: [0, 0, 1])
                    let combinedQ = pitchQ * rollQ
                    let tiltedRot = combinedQ * stickWorldRot
                    
                    let wristPos = currentWristWorldPos ?? handPos
                    comp.initialGripOffset = tiltedRot.inverse.act(wristPos - stickWorldPos)
                } else {
                    // Spring centering
                    comp.currentPitch -= comp.currentPitch * comp.springCenteringRatio
                    comp.currentRoll -= comp.currentRoll * comp.springCenteringRatio
                    if abs(comp.currentPitch) < 0.001 { comp.currentPitch = 0 }
                    if abs(comp.currentRoll) < 0.001 { comp.currentRoll = 0 }
                }
            } else {
                if isGripping, let handPos = currentHandWorldPos {
                    // Delta math for pitch/roll in WORLD SPACE to bypass crazy local coordinate rotations
                    let worldDelta = handPos - comp.previousHandWorldPosition
                    
                    // Moving forward is -Z in world space. We want this to tilt forward (negative pitch angle).
                    let deltaPitch = (worldDelta.z / comp.stickRadius) * comp.sensitivity
                    // Moving right is +X in world space. We want this to roll right.
                    let deltaRoll = (worldDelta.x / comp.stickRadius) * comp.sensitivity
                    
                    comp.currentPitch += deltaPitch
                    comp.currentRoll += deltaRoll
                    
                    comp.currentPitch = max(-comp.maxPitch, min(comp.currentPitch, comp.maxPitch))
                    comp.currentRoll = max(-comp.maxRoll, min(comp.currentRoll, comp.maxRoll))
                    
                    comp.previousHandWorldPosition = handPos
                } else {
                    // Release
                    comp.isLocked = false
                    comp.activeChirality = -1
                    comp.initialGripOffset = nil
                    
                    // Clear snap targets
                    if var hc = handComp {
                        hc.leftSnapPosition = nil
                        hc.leftSnapOrientation = nil
                        hc.rightSnapPosition = nil
                        hc.rightSnapOrientation = nil
                        handEntity?.components.set(hc)
                        handComp = hc
                    }
                }
            }
            
            // ── APPLY BONE ROTATION (existing logic) ────────────────────────
            let pitchQ = simd_quatf(angle: comp.currentPitch, axis: [1, 0, 0])
            let rollQ = simd_quatf(angle: -comp.currentRoll, axis: [0, 0, 1])
            let combinedQ = pitchQ * rollQ
            
            if let pivot = comp.pivotEntity, let model = pivot as? ModelEntity, !model.jointTransforms.isEmpty {
                let jointIdx = min(comp.boneIndex, model.jointTransforms.count - 1)
                if comp.initialBoneRotation == nil {
                    comp.initialBoneRotation = model.jointTransforms[jointIdx].rotation
                }
                let initial = comp.initialBoneRotation!
                var transforms = model.jointTransforms
                transforms[jointIdx].rotation = combinedQ * initial
                model.jointTransforms = transforms
                
            }
            
            // ── CALCULATE SOCKET WORLD POS MATHEMATICALLY ──────────────────────
            if comp.isLocked, var hands = handComp {
                let isLeft = comp.activeChirality == 0
                
                let stickWorldPos = entity.position(relativeTo: nil)
                let stickWorldRot = entity.orientation(relativeTo: nil)
                
                // The physical stick tilts from its upright neutral position
                let tiltedRot = combinedQ * stickWorldRot
                
                // We use the exact offset where they physically grabbed the stick
                let socketOffset = comp.initialGripOffset ?? SIMD3<Float>(0.0, 0.15, 0.02)
                let socketPos = stickWorldPos + tiltedRot.act(socketOffset)
                
                // For the grip rotation, we DO NOT force a rotation anymore!
                // The user's real wrist naturally aligns with the physical stick.
                // We just let ARKit track the wrist orientation, which prevents the 9 o'clock bug.
                
                print("🕹️ [JoystickSystem] Locked! Math Socket Pos: \(socketPos)")
                
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
