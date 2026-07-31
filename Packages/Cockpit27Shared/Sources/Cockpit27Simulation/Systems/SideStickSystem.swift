import RealityKit
import ARKit
import simd
import Cockpit27Core

@MainActor
public class SideStickSystem: System {
    private static let query = EntityQuery(where: .has(SideStickComponent.self))
    
    private static let handQuery = EntityQuery(where: .has(HandModelComponent.self))
    
    private let handTrackingService: HandTracking27ServiceProtocol?
    private let audioService: Audio27ServiceProtocol
    private let telemetryService: Cockpit27TelemetryProtocol
    
    public required init(scene: RealityKit.Scene) {
        self.handTrackingService = DependencyContainer.shared.tryResolve(HandTracking27ServiceProtocol.self)
        self.audioService = DependencyContainer.shared.resolve(Audio27ServiceProtocol.self)
        self.telemetryService = DependencyContainer.shared.resolve(Cockpit27TelemetryProtocol.self)
    }
    
    public func update(context: SceneUpdateContext) {
        let leftHandData = handTrackingService?.latestLeftHand
        let rightHandData = handTrackingService?.latestRightHand
        
        var handComp: HandModelComponent?
        var handEntity: Entity?
        for entity in context.scene.performQuery(Self.handQuery) {
            handComp = entity.components[HandModelComponent.self]
            handEntity = entity
            break
        }
        
        for entity in context.scene.performQuery(Self.query) {
            var comp = entity.components[SideStickComponent.self]!
            var tag = entity.components[CockpitControlTagComponent.self]
            
            let targetEntity = comp.pivotEntity ?? entity
            let handleTarget = comp.handleMeshEntity ?? targetEntity
            
            var activeHandPos: SIMD3<Float>? = nil
            var isInteracting = false
            var isPinching = false
            var currentChirality = comp.activeChirality
            
            let handDataList = [leftHandData, rightHandData].compactMap { $0 }
            for handData in handDataList where handData.isTracked {
                let tipPos = handData.indexTipWorldPos ?? handData.palmWorldPos
                guard let tip = tipPos else { continue }
                
                var pinchDist: Float = 1.0
                if let t = handData.thumbTipWorldPos, let i = handData.indexTipWorldPos {
                    pinchDist = simd_distance(t, i)
                }
                
                // Calculate precise hit zone using visual bounds of handle mesh combined with handleLocalOffset
                let pivotTransform = targetEntity.transformMatrix(relativeTo: nil)
                let bounds = handleTarget.visualBounds(relativeTo: nil)
                let meshCenter = bounds.center
                let customOffset = simd_mul(pivotTransform, SIMD4<Float>(comp.handleLocalOffset, 0.0))
                let gripWorldPos = bounds.extents.y > 0.01 
                    ? (meshCenter + SIMD3<Float>(customOffset.x, customOffset.y, customOffset.z))
                    : SIMD3<Float>(simd_mul(pivotTransform, SIMD4<Float>(comp.handleLocalOffset, 1.0)).x, simd_mul(pivotTransform, SIMD4<Float>(comp.handleLocalOffset, 1.0)).y, simd_mul(pivotTransform, SIMD4<Float>(comp.handleLocalOffset, 1.0)).z)
                
                let maxExtent = max(bounds.extents.x, max(bounds.extents.y, bounds.extents.z))
                let triggerRadius: Float = max(0.12, maxExtent * 0.5 + 0.05)
                
                let isInside = simd_distance(tip, gripWorldPos) < triggerRadius
                let isContinuingGrab = (comp.isGrabbed && comp.activeChirality == handData.chirality)
                
                if isInside || isContinuingGrab {
                    isInteracting = true
                    activeHandPos = tip
                    currentChirality = handData.chirality
                    if pinchDist < 0.045 {
                        isPinching = true
                    }
                    break
                }
            }
            
            var targetPitch = comp.currentPitch
            var targetRoll = comp.currentRoll
            
            if isInteracting, let handPos = activeHandPos {
                if comp.isGrabbed && !isPinching {
                    // Let go of pinch
                    comp.isGrabbed = false
                    comp.activeChirality = -1
                    comp.initialGripOffset = handPos // Reset offset so push isn't jerky
                    
                    if var hc = handComp {
                        if currentChirality == 0 { hc.leftSnapPosition = nil; hc.leftSnapBlend = 0.0 }
                        else if currentChirality == 1 { hc.rightSnapPosition = nil; hc.rightSnapBlend = 0.0 }
                        handEntity?.components.set(hc)
                        handComp = hc
                    }
                } else if !comp.isGrabbed && isPinching {
                    // Just pinched inside bounds
                    comp.isGrabbed = true
                    comp.activeChirality = currentChirality
                    comp.initialGripOffset = handPos
                } else if comp.initialGripOffset == nil {
                    // Just pushing
                    comp.initialGripOffset = handPos
                }
                
                let deltaWorld = handPos - comp.initialGripOffset!
                let pitchLimit = comp.maxPitchDegrees * (.pi / 180.0)
                let rollLimit = comp.maxRollDegrees * (.pi / 180.0)
                
                let pitchDelta = (deltaWorld.z / 0.10) * pitchLimit
                let rollDelta = -(deltaWorld.x / 0.10) * rollLimit
                
                targetPitch = max(-pitchLimit, min(pitchLimit, comp.currentPitch + pitchDelta))
                targetRoll = max(-rollLimit, min(rollLimit, comp.currentRoll + rollDelta))
                
                comp.initialGripOffset = handPos
                
            } else {
                if comp.springReturnToCenter {
                    targetPitch *= 0.85
                    targetRoll *= 0.85
                }
                
                // Released out of bounds
                comp.initialGripOffset = nil
                comp.isGrabbed = false
                if comp.activeChirality != -1, var hc = handComp {
                    if comp.activeChirality == 0 { hc.leftSnapPosition = nil; hc.leftSnapBlend = 0.0 }
                    else if comp.activeChirality == 1 { hc.rightSnapPosition = nil; hc.rightSnapBlend = 0.0 }
                    handEntity?.components.set(hc)
                    handComp = hc
                }
                comp.activeChirality = -1
            }
            
            comp.currentPitch = targetPitch
            comp.currentRoll = targetRoll
            
            let pitchQuat = simd_quatf(angle: targetPitch, axis: SIMD3<Float>(1, 0, 0))
            let rollQuat = simd_quatf(angle: targetRoll, axis: SIMD3<Float>(0, 0, 1))
            let finalQuat = pitchQuat * rollQuat
            
            if let pivot = comp.pivotEntity {
                if let model = pivot as? ModelEntity, !model.jointTransforms.isEmpty {
                    let jointIdx = min(comp.boneIndex, model.jointTransforms.count - 1)
                    if comp.initialBoneRotation == nil {
                        comp.initialBoneRotation = model.jointTransforms[jointIdx].rotation
                    }
                    let initial = comp.initialBoneRotation!
                    var transforms = model.jointTransforms
                    transforms[jointIdx].rotation = finalQuat * initial
                    model.jointTransforms = transforms
                } else {
                    pivot.transform.rotation = finalQuat
                }
            } else {
                targetEntity.transform.rotation = finalQuat
            }
            
            // Snap hand model to exact grip offset if grabbed
            if comp.isGrabbed, var hc = handComp {
                let pivotTransform = targetEntity.transformMatrix(relativeTo: nil)
                let bounds = handleTarget.visualBounds(relativeTo: nil)
                let meshCenter = bounds.center
                let customOffset = simd_mul(pivotTransform, SIMD4<Float>(comp.handleLocalOffset, 0.0))
                let socketPos = bounds.extents.y > 0.01 
                    ? (meshCenter + SIMD3<Float>(customOffset.x, customOffset.y, customOffset.z))
                    : SIMD3<Float>(simd_mul(pivotTransform, SIMD4<Float>(comp.handleLocalOffset, 1.0)).x, simd_mul(pivotTransform, SIMD4<Float>(comp.handleLocalOffset, 1.0)).y, simd_mul(pivotTransform, SIMD4<Float>(comp.handleLocalOffset, 1.0)).z)
                
                if comp.activeChirality == 0 {
                    hc.leftSnapPosition = socketPos
                    hc.leftSnapBlend = 1.0
                } else if comp.activeChirality == 1 {
                    hc.rightSnapPosition = socketPos
                    hc.rightSnapBlend = 1.0
                }
                handEntity?.components.set(hc)
                handComp = hc
            }
            
            entity.components.set(comp)
            
            // Telemetry & Tag component update
            if var controlTag = tag {
                let maxAngle = max(comp.maxPitchDegrees, comp.maxRollDegrees) * (.pi / 180.0)
                let norm = maxAngle > 0 ? min(1.0, max(0.0, (targetPitch + maxAngle) / (2 * maxAngle))) : 0.0
                
                if abs(controlTag.normalizedValue - norm) > 0.01 {
                    controlTag.normalizedValue = norm
                    controlTag.isHandAttached = isInteracting
                    entity.components.set(controlTag)
                    telemetryService.reportControlStateChanged(controlID: comp.controlID, normalizedValue: norm, stateIndex: nil)
                }
            }
        }
    }
}
