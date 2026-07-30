import RealityKit
import ARKit
import UIKit
import ILSHandTracking

public class HandTrackingSystem: System {
    private static let handQuery = EntityQuery(where: .has(HandModelComponent.self))
    
    public required init(scene: RealityKit.Scene) {}
    
    public func update(context: SceneUpdateContext) {
        let entities = context.scene.performQuery(Self.handQuery)
        
        let leftHandAnchor = CockpitHandTracking.currentService?.latestLeftHand
        let rightHandAnchor = CockpitHandTracking.currentService?.latestRightHand
        
        for entity in entities {
            guard var handComp = entity.components[HandModelComponent.self] else { continue }
            
            updateGlove(handComp.leftGlove,
                        with: leftHandAnchor,
                        isPinching: &handComp.isLeftPinching,
                        pinchPos: &handComp.leftPinchPosition,
                        pinchCentroid: &handComp.leftPinchCentroid,
                        pinchDistance: &handComp.leftPinchDistance,
                        fingerStatus: &handComp.leftFingerStatus,
                        originalMaterials: handComp.originalLeftMaterials,
                        snapPos: handComp.leftSnapPosition,
                        snapRot: handComp.leftSnapOrientation,
                        targetGripPose: handComp.leftTargetGripPose,
                        snapBlend: handComp.leftSnapBlend,
                        indexCollider: handComp.leftIndexCollider,
                        thumbCollider: handComp.leftThumbCollider,
                        palmCollider: handComp.leftPalmCollider,
                        side: "Left")
            
            updateGlove(handComp.rightGlove,
                        with: rightHandAnchor,
                        isPinching: &handComp.isRightPinching,
                        pinchPos: &handComp.rightPinchPosition,
                        pinchCentroid: &handComp.rightPinchCentroid,
                        pinchDistance: &handComp.rightPinchDistance,
                        fingerStatus: &handComp.rightFingerStatus,
                        originalMaterials: handComp.originalRightMaterials,
                        snapPos: handComp.rightSnapPosition,
                        snapRot: handComp.rightSnapOrientation,
                        targetGripPose: handComp.rightTargetGripPose,
                        snapBlend: handComp.rightSnapBlend,
                        indexCollider: handComp.rightIndexCollider,
                        thumbCollider: handComp.rightThumbCollider,
                        palmCollider: handComp.rightPalmCollider,
                        side: "Right")
            
            entity.components.set(handComp)
        }
    }

    
    @MainActor
    private func updateGlove(_ glove: ModelEntity?, with anchor: HandAnchor?, isPinching: inout Bool, pinchPos: inout SIMD3<Float>, pinchCentroid: inout SIMD3<Float>, pinchDistance: inout Float, fingerStatus: inout [Bool], originalMaterials: [Material], snapPos: SIMD3<Float>?, snapRot: simd_quatf?, targetGripPose: String?, snapBlend: Float, indexCollider: Entity?, thumbCollider: Entity?, palmCollider: Entity?, side: String) {
        guard let glove = glove else { return }
        
        guard let anchor = anchor, anchor.isTracked, let skeleton = anchor.handSkeleton else {
            glove.isEnabled = false
            isPinching = false
            return
        }
        
        glove.isEnabled = true
        
        // ── UPDATE PERSISTENT TRIGGER COLLIDERS & PINCH CENTROID ─────────────
        let worldMatrix = anchor.originFromAnchorTransform
        let idxColPos = (worldMatrix * skeleton.joint(.indexFingerTip).anchorFromJointTransform).columns.3
        let thmColPos = (worldMatrix * skeleton.joint(.thumbTip).anchorFromJointTransform).columns.3
        
        let indexTipWorld = SIMD3<Float>(idxColPos.x, idxColPos.y, idxColPos.z)
        let thumbTipWorld = SIMD3<Float>(thmColPos.x, thmColPos.y, thmColPos.z)
        
        let (centroid, dist) = KnobGestureMath.computePinchCentroidAndDistance(thumb: thumbTipWorld, index: indexTipWorld)
        pinchCentroid = centroid
        pinchDistance = dist
        
        if let idxCol = indexCollider {
            idxCol.setPosition(indexTipWorld, relativeTo: nil)
        }
        if let thmCol = thumbCollider {
            thmCol.setPosition(thumbTipWorld, relativeTo: nil)
        }
        if let plmCol = palmCollider {
            let col = (worldMatrix * skeleton.joint(.middleFingerKnuckle).anchorFromJointTransform).columns.3
            plmCol.setPosition(SIMD3<Float>(col.x, col.y, col.z), relativeTo: nil)
        }


        
        // ── TRANSFORM ────────────────────────────────────────────────────────
        let arkitMatrix = anchor.originFromAnchorTransform
        if let pos = snapPos {
            glove.setPosition(pos, relativeTo: nil)
            
            if let rot = snapRot {
                glove.setOrientation(rot, relativeTo: nil)
            } else {
                glove.setOrientation(Transform(matrix: arkitMatrix).rotation, relativeTo: nil)
            }
            print("🧤 [HandTrackingSystem] [\(side) Glove] SNAPPING to Pos: \(pos)")
        } else {
            glove.transform = Transform(matrix: arkitMatrix)
        }
        
        // ── JOINTS ───────────────────────────────────────────────────────────
        let joints = skeleton.allJoints
        
        if !glove.jointNames.isEmpty {
            for (index, jointName) in glove.jointNames.enumerated() {
                if index < glove.jointTransforms.count {
                    if let arkitJoint = joints.first(where: { $0.name.description == jointName || jointName.contains($0.name.description) }) {
                        let jointTransform = arkitJoint.parentFromJointTransform
                        glove.jointTransforms[index].rotation = simd_quatf(jointTransform)
                    } else if index < joints.count {
                        let jointTransform = joints[index].parentFromJointTransform
                        glove.jointTransforms[index].rotation = simd_quatf(jointTransform)
                    }
                }
            }
        }

        
        let isIndexCurled = isFingerCurled(skeleton: skeleton, tip: .indexFingerTip, knuckle: .indexFingerKnuckle)
        let isMiddleCurled = isFingerCurled(skeleton: skeleton, tip: .middleFingerTip, knuckle: .middleFingerKnuckle)
        let isRingCurled = isFingerCurled(skeleton: skeleton, tip: .ringFingerTip, knuckle: .ringFingerKnuckle)
        let isLittleCurled = isFingerCurled(skeleton: skeleton, tip: .littleFingerTip, knuckle: .littleFingerKnuckle)
        
        fingerStatus = [isIndexCurled, isMiddleCurled, isRingCurled, isLittleCurled]
        
        let totalCurled = (isIndexCurled ? 1 : 0) + (isMiddleCurled ? 1 : 0) + (isRingCurled ? 1 : 0) + (isLittleCurled ? 1 : 0)
        let wasPinching = isPinching
        isPinching = totalCurled >= 3
        
        if isPinching != wasPinching {
            print("[\(side) Glove] Grab State Changed: \(isPinching) (Index: \(isIndexCurled), Middle: \(isMiddleCurled), Ring: \(isRingCurled), Little: \(isLittleCurled))")
        }
        
        let palmJoint = skeleton.joint(.middleFingerKnuckle)
        let palmCol = (anchor.originFromAnchorTransform * palmJoint.anchorFromJointTransform).columns.3
        pinchPos = SIMD3<Float>(palmCol.x, palmCol.y, palmCol.z)
        
        if isPinching && !wasPinching {
            let material = SimpleMaterial(color: .green.withAlphaComponent(0.8), isMetallic: false)
            glove.model?.materials = [material]
        } else if !isPinching && wasPinching {
            glove.model?.materials = originalMaterials
        }
    }
    
    private func isFingerCurled(skeleton: HandSkeleton, tip: HandSkeleton.JointName, knuckle: HandSkeleton.JointName) -> Bool {
        let tipJoint = skeleton.joint(tip)
        let knuckleJoint = skeleton.joint(knuckle)
        let wristJoint = skeleton.joint(.wrist)
        
        let tipCol = tipJoint.anchorFromJointTransform.columns.3
        let knuckleCol = knuckleJoint.anchorFromJointTransform.columns.3
        let wristCol = wristJoint.anchorFromJointTransform.columns.3
        
        let tipDist = simd_distance(SIMD3<Float>(tipCol.x, tipCol.y, tipCol.z),
                                    SIMD3<Float>(wristCol.x, wristCol.y, wristCol.z))
        let knuckleDist = simd_distance(SIMD3<Float>(knuckleCol.x, knuckleCol.y, knuckleCol.z),
                                        SIMD3<Float>(wristCol.x, wristCol.y, wristCol.z))
        
        return tipDist < knuckleDist
    }
    
    private func getPoseQuat(for jointName: HandSkeleton.JointName, poseName: String, isLeft: Bool) -> simd_quatf? {
        guard poseName == "PowerGrip" else { return nil }
        
        let name = jointName.description
        if name.contains("Proximal") || name.contains("Intermediate") {
            // Very rough approximation for curling (approx 60 degrees around local axis)
            // A more exact approach requires pre-authored animations, but this provides a visual cue.
            let curlAxis: SIMD3<Float> = isLeft ? [1, 0, 0] : [1, 0, 0] 
            return simd_quatf(angle: .pi / 3, axis: curlAxis)
        }
        return nil
    }
}
