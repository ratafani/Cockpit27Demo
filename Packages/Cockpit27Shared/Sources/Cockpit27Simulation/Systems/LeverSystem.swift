import RealityKit
import ARKit
import simd
import ILSHandTracking

@MainActor
public class LeverSystem: System {
    private static let query = EntityQuery(where: .has(LeverComponent.self))
    
    // EMA Smoothing for stability
    private var smoothedLeftPalmPos: SIMD3<Float>?
    private var smoothedRightPalmPos: SIMD3<Float>?
    private var previousLeftPalmPos: SIMD3<Float>?
    private var previousRightPalmPos: SIMD3<Float>?
    
    public required init(scene: RealityKit.Scene) {}
    
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
        
        var leftPalmRaw: SIMD3<Float>? = nil
        var rightPalmRaw: SIMD3<Float>? = nil
        
        if let anchor = leftHand, anchor.isTracked, let skeleton = anchor.handSkeleton {
            let palmCol = (anchor.originFromAnchorTransform * skeleton.joint(.middleFingerKnuckle).anchorFromJointTransform).columns.3
            leftPalmRaw = SIMD3<Float>(palmCol.x, palmCol.y, palmCol.z)
        }
        if let anchor = rightHand, anchor.isTracked, let skeleton = anchor.handSkeleton {
            let palmCol = (anchor.originFromAnchorTransform * skeleton.joint(.middleFingerKnuckle).anchorFromJointTransform).columns.3
            rightPalmRaw = SIMD3<Float>(palmCol.x, palmCol.y, palmCol.z)
        }
        
        previousLeftPalmPos = smoothedLeftPalmPos
        previousRightPalmPos = smoothedRightPalmPos
        
        if let p = leftPalmRaw { smoothedLeftPalmPos = smoothedLeftPalmPos.map { $0 * 0.8 + p * 0.2 } ?? p } else { smoothedLeftPalmPos = nil; previousLeftPalmPos = nil }
        if let p = rightPalmRaw { smoothedRightPalmPos = smoothedRightPalmPos.map { $0 * 0.8 + p * 0.2 } ?? p } else { smoothedRightPalmPos = nil; previousRightPalmPos = nil }
        
        let isLeftCurled = isHandCurled(skeleton: leftHand?.handSkeleton)
        let isRightCurled = isHandCurled(skeleton: rightHand?.handSkeleton)
        
        for entity in context.scene.performQuery(Self.query) {
            var comp = entity.components[LeverComponent.self]!
            let worldPos = entity.position(relativeTo: nil)
            
            // Mathematical Distance Check
            let triggerRadius: Float = 0.20 // 20cm trigger zone
            
            var isLeftNear = false
            var isRightNear = false
            
            if let lp = smoothedLeftPalmPos, simd_distance(lp, worldPos) < triggerRadius { isLeftNear = true }
            if let rp = smoothedRightPalmPos, simd_distance(rp, worldPos) < triggerRadius { isRightNear = true }
            
            let primarySide: HandAnchor.Chirality? = isLeftNear ? .left : (isRightNear ? .right : nil)
            
            guard let side = primarySide else {
                if comp.isGrabbed { comp.isGrabbed = false }
                entity.components.set(comp)
                continue
            }
            
            let isCurled = side == .left ? isLeftCurled : isRightCurled
            let currentPalm = side == .left ? smoothedLeftPalmPos : smoothedRightPalmPos
            let previousPalm = side == .left ? previousLeftPalmPos : previousRightPalmPos
            
            // Grab state machine
            if comp.isGrabbed {
                if !isCurled || currentPalm == nil { comp.isGrabbed = false }
            } else {
                if isCurled {
                    comp.isGrabbed = true
                }
            }
            
            if comp.isGrabbed, let currentWorld = currentPalm {
                let parentEntity = entity.parent ?? entity
                let localCurrent = parentEntity.convert(position: currentWorld, from: nil)
                let localPrevious = previousPalm != nil ? parentEntity.convert(position: previousPalm!, from: nil) : localCurrent
                let localDelta = localCurrent - localPrevious
                
                guard simd_length(localDelta) > 0.0001 else { entity.components.set(comp); continue }
                
                let linearMovement = -localDelta.z
                let deltaTheta = (linearMovement / comp.leverRadius) * comp.sensitivity
                var targetAngle = comp.currentAngle + deltaTheta
                
                for detent in comp.detents {
                    if abs(targetAngle - detent) < comp.detentTolerance { targetAngle = detent; break }
                }
                comp.currentAngle = max(0, min(targetAngle, comp.maxAngle))
                
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
            }
            entity.components.set(comp)
        }
    }
}
