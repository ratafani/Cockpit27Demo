import RealityKit
import ARKit
import simd
import Cockpit27Core

@MainActor
public class SideStickSystem: System {
    private static let query = EntityQuery(where: .has(SideStickComponent.self))
    
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
        
        for entity in context.scene.performQuery(Self.query) {
            var comp = entity.components[SideStickComponent.self]!
            var tag = entity.components[CockpitControlTagComponent.self]
            
            let targetEntity = comp.pivotEntity ?? entity
            let handleTarget = comp.handleMeshEntity ?? targetEntity
            let handleWorldPos = handleTarget.transformMatrix(relativeTo: nil).columns.3
            let handlePos3D = SIMD3<Float>(handleWorldPos.x, handleWorldPos.y, handleWorldPos.z)
            
            var activeHandPos: SIMD3<Float>? = nil
            var isInteracting = false
            
            let handDataList = [leftHandData, rightHandData].compactMap { $0 }
            for handData in handDataList where handData.isTracked {
                let tipPos = handData.indexTipWorldPos ?? handData.palmWorldPos
                guard let tip = tipPos else { continue }
                
                if isPointInsideEntity(tip, entity: handleTarget, padding: 0.0) {
                    isInteracting = true
                    activeHandPos = tip
                    break
                }
            }
            
            var targetPitch = comp.currentPitch
            var targetRoll = comp.currentRoll
            
            if isInteracting, let handPos = activeHandPos {
                if !comp.isGrabbed {
                    // Just grabbed
                    comp.initialGripOffset = handPos
                    comp.isGrabbed = true
                }
                
                // Calculate drag delta purely in World Space to avoid USD internal rotation issues
                let deltaWorld = handPos - comp.initialGripOffset!
                
                let pitchLimit = comp.maxPitchDegrees * (.pi / 180.0)
                let rollLimit = comp.maxRollDegrees * (.pi / 180.0)
                
                // Map linear delta to angle delta. 10cm movement = max angle
                // World +Z is backward (pulling stick back). World -Z is forward (pushing stick forward).
                // Pitch: Pulling back (+Z) = Positive Pitch. Pushing forward (-Z) = Negative Pitch.
                let pitchDelta = (deltaWorld.z / 0.10) * pitchLimit
                
                // World +X is Right. World -X is Left. 
                // The user reported left went right, so we invert the X delta mapping here.
                let rollDelta = -(deltaWorld.x / 0.10) * rollLimit
                
                targetPitch = max(-pitchLimit, min(pitchLimit, comp.currentPitch + pitchDelta))
                targetRoll = max(-rollLimit, min(rollLimit, comp.currentRoll + rollDelta))
                
                // Update grip offset for next frame so it acts incrementally
                comp.initialGripOffset = handPos
                
            } else if comp.springReturnToCenter {
                // Smooth spring return to center
                targetPitch *= 0.85
                targetRoll *= 0.85
                comp.isGrabbed = false
            }
            
            comp.currentPitch = targetPitch
            comp.currentRoll = targetRoll
            comp.isGrabbed = isInteracting
            // Update rotation
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
