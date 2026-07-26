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
            
            updateGlove(handComp.leftGlove, with: leftHandAnchor, 
                        isPinching: &handComp.isLeftPinching, 
                        pinchPos: &handComp.leftPinchPosition, 
                        fingerStatus: &handComp.leftFingerStatus, 
                        originalMaterials: handComp.originalLeftMaterials, 
                        snapPos: handComp.leftSnapPosition,
                        snapRot: handComp.leftSnapOrientation,
                        side: "Left")
            
            updateGlove(handComp.rightGlove, with: rightHandAnchor, 
                        isPinching: &handComp.isRightPinching, 
                        pinchPos: &handComp.rightPinchPosition, 
                        fingerStatus: &handComp.rightFingerStatus, 
                        originalMaterials: handComp.originalRightMaterials, 
                        snapPos: handComp.rightSnapPosition,
                        snapRot: handComp.rightSnapOrientation,
                        side: "Right")
            
            entity.components.set(handComp)
        }
    }
    
    @MainActor
    private func updateGlove(_ glove: ModelEntity?, with anchor: HandAnchor?, isPinching: inout Bool, pinchPos: inout SIMD3<Float>, fingerStatus: inout [Bool], originalMaterials: [Material], snapPos: SIMD3<Float>?, snapRot: simd_quatf?, side: String) {
        guard let glove = glove else { return }
        
        guard let anchor = anchor, anchor.isTracked, let skeleton = anchor.handSkeleton else {
            glove.isEnabled = false
            isPinching = false
            return
        }
        
        glove.isEnabled = true
        
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
        let expectedJointCount = HandSkeleton.JointName.allCases.count
        
        if glove.jointNames.count == expectedJointCount {
            // Live ARKit Fingers (always active, even when root is snapped!)
            for (index, joint) in joints.enumerated() {
                let jointTransform = skeleton.joint(joint.name).parentFromJointTransform
                glove.jointTransforms[index].rotation = simd_quatf(jointTransform)
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
            var material = SimpleMaterial(color: .green.withAlphaComponent(0.8), isMetallic: false)
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
}
