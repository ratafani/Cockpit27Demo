import RealityKit
import ARKit
import simd
import ILSHandTracking

public class CockpitInteractionSystem: System {
    private static let query = EntityQuery(where: .has(CockpitInteractionComponent.self))
    
    public required init(scene: RealityKit.Scene) {}
    
    public func update(context: SceneUpdateContext) {
        let entities = context.scene.performQuery(Self.query)
        
        let leftHand = HandTrackingService.shared.latestLeftHand
        let rightHand = HandTrackingService.shared.latestRightHand
        
        for entity in entities {
            guard var component = entity.components[CockpitInteractionComponent.self] else { continue }
            
            // Handle Sidestick (Left Hand)
            var leftPinchPos: SIMD3<Float>? = nil
            var isLeftCurled = false
            
            if let anchor = leftHand, anchor.isTracked, let skeleton = anchor.handSkeleton {
                let index = isFingerCurled(skeleton: skeleton, tip: .indexFingerTip, knuckle: .indexFingerKnuckle)
                let middle = isFingerCurled(skeleton: skeleton, tip: .middleFingerTip, knuckle: .middleFingerKnuckle)
                let ring = isFingerCurled(skeleton: skeleton, tip: .ringFingerTip, knuckle: .ringFingerKnuckle)
                let little = isFingerCurled(skeleton: skeleton, tip: .littleFingerTip, knuckle: .littleFingerKnuckle)
                
                let curledCount = (index ? 1 : 0) + (middle ? 1 : 0) + (ring ? 1 : 0) + (little ? 1 : 0)
                isLeftCurled = curledCount >= 3
                
                let palmJoint = skeleton.joint(.middleFingerKnuckle)
                let palmCol = (anchor.originFromAnchorTransform * palmJoint.anchorFromJointTransform).columns.3
                leftPinchPos = SIMD3<Float>(palmCol.x, palmCol.y, palmCol.z)
            }
            
            if isLeftCurled, let pinchPos = leftPinchPos {
                if !component.isSidestickGrabbed {
                    if let sidestick = component.sidestickEntity {
                        let sidestickWorldPos = sidestick.visualBounds(relativeTo: nil).center
                        if simd_distance(pinchPos, sidestickWorldPos) < 0.35 { // 35cm grab radius
                            component.isSidestickGrabbed = true
                            component.initialLeftPinchPos = pinchPos
                            if component.initialSidestickRotation == nil {
                                component.initialSidestickRotation = sidestick.transform.rotation
                            }
                        }
                    }
                }
                
                if component.isSidestickGrabbed, let initialPos = component.initialLeftPinchPos {
                    let delta = pinchPos - initialPos
                    
                    let pitchAngle = (delta.z / 0.1) * (Float.pi / 6)
                    let rollAngle = -(delta.x / 0.1) * (Float.pi / 6)
                    
                    let clampedPitch = max(-Float.pi/9, min(Float.pi/9, pitchAngle))
                    let clampedRoll = max(-Float.pi/9, min(Float.pi/9, rollAngle))
                    
                    let rotation = simd_quatf(angle: clampedPitch, axis: [1, 0, 0]) * simd_quatf(angle: clampedRoll, axis: [0, 0, 1])
                    
                    // 1. Joint animation if model entity exists
                    if let model = component.sidestickModelEntity, let jointIndex = component.sidestickJointIndex, model.jointNames.count > jointIndex {
                        var transforms = model.jointTransforms
                        transforms[jointIndex].rotation = rotation
                        model.jointTransforms = transforms
                    } else if let sidestick = component.sidestickEntity {
                        // 2. Direct transform rotation fallback
                        if component.initialSidestickRotation == nil {
                            component.initialSidestickRotation = sidestick.transform.rotation
                        }
                        if let initialRot = component.initialSidestickRotation {
                            sidestick.transform.rotation = initialRot * rotation
                        }
                    }
                    
                    if let initialButtonRot = component.initialButtonRigRotation {
                        component.buttonRigEntity?.transform.rotation = initialButtonRot * rotation
                    }
                    
                    component.sidestickDisplacement = SIMD2<Float>(
                        max(-1, min(1, delta.x / 0.1)),
                        max(-1, min(1, delta.z / 0.1))
                    )
                }
            } else {
                component.isSidestickGrabbed = false
                component.initialLeftPinchPos = nil
                component.sidestickDisplacement = .zero
                
                // Spring loaded return
                if let model = component.sidestickModelEntity, let jointIndex = component.sidestickJointIndex, model.jointNames.count > jointIndex {
                    var transforms = model.jointTransforms
                    let currentRot = transforms[jointIndex].rotation
                    transforms[jointIndex].rotation = simd_slerp(currentRot, simd_quatf(angle: 0, axis: [1,0,0]), 0.15)
                    model.jointTransforms = transforms
                } else if let sidestick = component.sidestickEntity, let initialRot = component.initialSidestickRotation {
                    sidestick.transform.rotation = simd_slerp(sidestick.transform.rotation, initialRot, 0.15)
                }
                
                if let currentRot = component.buttonRigEntity?.transform.rotation, let initialRot = component.initialButtonRigRotation {
                    component.buttonRigEntity?.transform.rotation = simd_slerp(currentRot, initialRot, 0.15)
                }
            }
            
            // Handle Throttle (Right Hand)
            var rightPinchPos: SIMD3<Float>? = nil
            var isRightCurled = false
            
            if let anchor = rightHand, anchor.isTracked, let skeleton = anchor.handSkeleton {
                let index = isFingerCurled(skeleton: skeleton, tip: .indexFingerTip, knuckle: .indexFingerKnuckle)
                let middle = isFingerCurled(skeleton: skeleton, tip: .middleFingerTip, knuckle: .middleFingerKnuckle)
                let ring = isFingerCurled(skeleton: skeleton, tip: .ringFingerTip, knuckle: .ringFingerKnuckle)
                let little = isFingerCurled(skeleton: skeleton, tip: .littleFingerTip, knuckle: .littleFingerKnuckle)
                
                let curledCount = (index ? 1 : 0) + (middle ? 1 : 0) + (ring ? 1 : 0) + (little ? 1 : 0)
                isRightCurled = curledCount >= 3
                
                let palmJoint = skeleton.joint(.middleFingerKnuckle)
                let palmCol = (anchor.originFromAnchorTransform * palmJoint.anchorFromJointTransform).columns.3
                rightPinchPos = SIMD3<Float>(palmCol.x, palmCol.y, palmCol.z)
            }
            
            if isRightCurled, let pinchPos = rightPinchPos {
                let leftThrottleEntity = component.throttleEntity
                let rightThrottleEntity = component.throttleRightEntity
                
                let distL = leftThrottleEntity.map { simd_distance(pinchPos, $0.visualBounds(relativeTo: nil).center) } ?? Float.infinity
                let distR = rightThrottleEntity.map { simd_distance(pinchPos, $0.visualBounds(relativeTo: nil).center) } ?? Float.infinity
                
                if !component.isThrottleLGrabbed && !component.isThrottleRGrabbed {
                    // Check if hand is near left lever
                    if distL < 0.30 && distL <= distR {
                        component.isThrottleLGrabbed = true
                        component.initialRightPinchPos = pinchPos
                        component.throttleLValueAtGrabStart = component.throttleLValue
                        if component.initialThrottleLRotation == nil, let t = leftThrottleEntity {
                            component.initialThrottleLRotation = t.transform.rotation
                        }
                    }
                    // Check if hand is near right lever
                    else if distR < 0.30 {
                        component.isThrottleRGrabbed = true
                        component.initialRightPinchPos = pinchPos
                        component.throttleRValueAtGrabStart = component.throttleRValue
                        if component.initialThrottleRRotation == nil, let tr = rightThrottleEntity {
                            component.initialThrottleRRotation = tr.transform.rotation
                        }
                    }
                }
                
                if component.isThrottleLGrabbed, let initialPos = component.initialRightPinchPos {
                    let delta = pinchPos - initialPos
                    let movementDelta = -(delta.z / 0.55) // Smooth sensitivity: 55cm travel range
                    component.throttleLValue = max(0.0, min(1.0, component.throttleLValueAtGrabStart + movementDelta))
                }
                
                if component.isThrottleRGrabbed, let initialPos = component.initialRightPinchPos {
                    let delta = pinchPos - initialPos
                    let movementDelta = -(delta.z / 0.55) // Smooth sensitivity: 55cm travel range
                    component.throttleRValue = max(0.0, min(1.0, component.throttleRValueAtGrabStart + movementDelta))
                }
            } else {
                component.isThrottleLGrabbed = false
                component.isThrottleRGrabbed = false
                component.initialRightPinchPos = nil
            }
            
            // Apply throttle rotation EVERY frame to respective lever
            if let throttleL = component.throttleEntity {
                if component.initialThrottleLRotation == nil {
                    component.initialThrottleLRotation = throttleL.transform.rotation
                }
                let angleL = (component.throttleLValue - 0.5) * (Float.pi / 2)
                let rotL = simd_quatf(angle: angleL, axis: [1, 0, 0])
                if let initialRotL = component.initialThrottleLRotation {
                    throttleL.transform.rotation = initialRotL * rotL
                }
            }
            
            if let throttleR = component.throttleRightEntity {
                if component.initialThrottleRRotation == nil {
                    component.initialThrottleRRotation = throttleR.transform.rotation
                }
                let angleR = (component.throttleRValue - 0.5) * (Float.pi / 2)
                let rotR = simd_quatf(angle: angleR, axis: [1, 0, 0])
                if let initialRotR = component.initialThrottleRRotation {
                    throttleR.transform.rotation = initialRotR * rotR
                }
            }
            
            entity.components.set(component)
        }
    }
    
    // Custom finger curled detection that ignores isTracked
    // ARKit loses track of fingertips when they are hidden in a fist,
    // but the estimated transform is still accurate enough for distance checks!
    private func isFingerCurled(skeleton: HandSkeleton, tip: HandSkeleton.JointName, knuckle: HandSkeleton.JointName) -> Bool {
        let tipJoint = skeleton.joint(tip)
        let knuckleJoint = skeleton.joint(knuckle)
        let wristJoint = skeleton.joint(.wrist)
        
        let tipCol = tipJoint.anchorFromJointTransform.columns.3
        let knuckleCol = knuckleJoint.anchorFromJointTransform.columns.3
        let wristCol = wristJoint.anchorFromJointTransform.columns.3
        
        let tipDistance = simd_distance(SIMD3<Float>(tipCol.x, tipCol.y, tipCol.z), SIMD3<Float>(wristCol.x, wristCol.y, wristCol.z))
        let knuckleDistance = simd_distance(SIMD3<Float>(knuckleCol.x, knuckleCol.y, knuckleCol.z), SIMD3<Float>(wristCol.x, wristCol.y, wristCol.z))
        
        return tipDistance < knuckleDistance
    }
}
