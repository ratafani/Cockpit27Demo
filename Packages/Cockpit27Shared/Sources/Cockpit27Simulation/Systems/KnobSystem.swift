import RealityKit
import simd
import Cockpit27Core

@MainActor
public class KnobSystem: System {
    private static let query = EntityQuery(where: .has(KnobComponent.self))
    
    private let handTrackingService: HandTracking27ServiceProtocol?
    private let audioService: Audio27ServiceProtocol
    private let telemetryService: Cockpit27TelemetryProtocol
    
    private var lastHandAngles: [Entity.ID: Float] = [:]
    
    public required init(scene: RealityKit.Scene) {
        self.handTrackingService = DependencyContainer.shared.tryResolve(HandTracking27ServiceProtocol.self)
        self.audioService = DependencyContainer.shared.resolve(Audio27ServiceProtocol.self)
        self.telemetryService = DependencyContainer.shared.resolve(Cockpit27TelemetryProtocol.self)
    }
    
    public func update(context: SceneUpdateContext) {
        let leftHand = handTrackingService?.latestLeftHand
        let rightHand = handTrackingService?.latestRightHand
        
        for entity in context.scene.performQuery(Self.query) {
            var comp = entity.components[KnobComponent.self]!
            let tag = entity.components[CockpitControlTagComponent.self]
            
            let targetEntity = comp.pivotEntity ?? entity
            let handleTarget = comp.handleMeshEntity ?? targetEntity
            
            let hands = [leftHand, rightHand].compactMap { $0 }
            var isGrabbing = false
            
            for hand in hands where hand.isTracked {
                let pinchTip = hand.thumbTipWorldPos ?? hand.indexTipWorldPos
                guard let tipPos = pinchTip else { continue }
                
                if isPointInsideEntity(tipPos, entity: handleTarget, padding: 0.02) {
                    isGrabbing = true
                    comp.gestureState = .twisting
                    
                    let parentTransform = targetEntity.parent?.transformMatrix(relativeTo: nil) ?? matrix_identity_float4x4
                    let inv = simd_inverse(parentTransform)
                    let localTip = simd_mul(inv, SIMD4<Float>(tipPos, 1.0))
                    
                    let currentHandX = localTip.x
                    if let lastX = lastHandAngles[entity.id] {
                        let deltaX = currentHandX - lastX
                        // Map 1cm of linear thumb movement to (sensitivity) degrees
                        comp.currentAngle += deltaX * (comp.sensitivity * 50.0) 
                        comp.currentAngle = max(comp.minAngle, min(comp.maxAngle, comp.currentAngle))
                    }
                    lastHandAngles[entity.id] = currentHandX
                    break
                }
            }
            
            if !isGrabbing {
                comp.gestureState = .idle
                lastHandAngles.removeValue(forKey: entity.id)
                
                // Snap to nearest detent when idle/released
                if !comp.detents.isEmpty {
                    var closestDetent = comp.currentAngle
                    var minDistance: Float = .greatestFiniteMagnitude
                    for detent in comp.detents {
                        let d = abs(comp.currentAngle - detent)
                        if d < minDistance {
                            minDistance = d
                            closestDetent = detent
                        }
                    }
                    if minDistance < 0.3 { // 0.3 rad (~17 degrees) snap window
                        if comp.currentAngle != closestDetent {
                            audioService.playDetentSnapSound(controlID: comp.controlID, position: handleTarget.position)
                        }
                        comp.currentAngle = closestDetent
                    }
                }
            }
            
            entity.components.set(comp)
            
            // Apply rotation transform on child pivotEntity
            let rotation = simd_quatf(angle: comp.currentAngle, axis: comp.localRotationAxis)
            targetEntity.transform.rotation = rotation
            
            // Update Telemetry & Tag
            if var controlTag = tag {
                let range = comp.maxAngle - comp.minAngle
                let norm = range > 0 ? (comp.currentAngle - comp.minAngle) / range : 0.0
                
                if abs(controlTag.normalizedValue - norm) > 0.01 {
                    controlTag.normalizedValue = norm
                    controlTag.isHandAttached = isGrabbing
                    entity.components.set(controlTag)
                    telemetryService.reportControlStateChanged(controlID: comp.controlID, normalizedValue: norm, stateIndex: nil)
                }
            }
        }
    }
}
