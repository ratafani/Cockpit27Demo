import RealityKit
import simd
import Cockpit27Core

@MainActor
public class SwitchSystem: System {
    private static let query = EntityQuery(where: .has(SwitchComponent.self))
    
    private let handTrackingService: HandTracking27ServiceProtocol?
    private let audioService: Audio27ServiceProtocol
    private let telemetryService: Cockpit27TelemetryProtocol
    
    private var isDebouncedMap: [Entity.ID: Bool] = [:]
    
    public required init(scene: RealityKit.Scene) {
        self.handTrackingService = DependencyContainer.shared.tryResolve(HandTracking27ServiceProtocol.self)
        self.audioService = DependencyContainer.shared.resolve(Audio27ServiceProtocol.self)
        self.telemetryService = DependencyContainer.shared.resolve(Cockpit27TelemetryProtocol.self)
    }
    
    public func update(context: SceneUpdateContext) {
        let leftHand = handTrackingService?.latestLeftHand
        let rightHand = handTrackingService?.latestRightHand
        
        for entity in context.scene.performQuery(Self.query) {
            var comp = entity.components[SwitchComponent.self]!
            let tag = entity.components[CockpitControlTagComponent.self]
            
            let targetEntity = comp.pivotEntity ?? entity
            let handleTarget = comp.handleMeshEntity ?? targetEntity
            
            let hands = [leftHand, rightHand].compactMap { $0 }
            var isTouchInteracting = false
            
            for hand in hands where hand.isTracked {
                let tipPos = hand.indexTipWorldPos ?? hand.palmWorldPos
                guard let tip = tipPos else { continue }
                if isPointInsideEntity(tip, entity: handleTarget, padding: 0.01) { // Native bounding box collision with 1cm padding
                    isTouchInteracting = true
                    
                    let isDebounced = isDebouncedMap[entity.id] ?? false
                    if !isDebounced {
                        isDebouncedMap[entity.id] = true
                        let nextIndex = (comp.currentStateIndex + 1) % max(1, comp.states.count)
                        comp.currentStateIndex = nextIndex
                        audioService.playClickSound(controlID: comp.controlID, position: handleTarget.position)
                    }
                    break
                }
            }
            
            if !isTouchInteracting {
                isDebouncedMap[entity.id] = false
            }
            
            entity.components.set(comp)
            
            // Set discrete state rotation on child pivot entity
            if comp.currentStateIndex < comp.states.count {
                let targetAngle = comp.states[comp.currentStateIndex]
                targetEntity.transform.rotation = simd_quatf(angle: targetAngle, axis: comp.localRotationAxis)
            }
            
            // Update telemetry and tag component
            if var controlTag = tag {
                let norm = Float(comp.currentStateIndex) / Float(max(1, comp.states.count - 1))
                if controlTag.currentStateIndex != comp.currentStateIndex {
                    controlTag.currentStateIndex = comp.currentStateIndex
                    controlTag.normalizedValue = norm
                    controlTag.isHandAttached = isTouchInteracting
                    entity.components.set(controlTag)
                    telemetryService.reportControlStateChanged(controlID: comp.controlID, normalizedValue: norm, stateIndex: comp.currentStateIndex)
                }
            }
        }
    }
}
