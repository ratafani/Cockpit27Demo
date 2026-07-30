import Foundation
import RealityKit
import ARKit
import ILSHandTracking
import Cockpit27Core

/// Live bridge converting CockpitHandTracking service anchors into HandTracking27ServiceProtocol for DI resolution
@MainActor
public class CockpitHandTrackingBridge: HandTracking27ServiceProtocol {
    public init() {}
    
    public var latestLeftHand: HandAnchorData? {
        guard let anchor = CockpitHandTracking.currentService?.latestLeftHand, anchor.isTracked else { return nil }
        return extractAnchorData(anchor: anchor, chirality: 0)
    }
    
    public var latestRightHand: HandAnchorData? {
        guard let anchor = CockpitHandTracking.currentService?.latestRightHand, anchor.isTracked else { return nil }
        return extractAnchorData(anchor: anchor, chirality: 1)
    }
    
    private func extractAnchorData(anchor: HandAnchor, chirality: Int) -> HandAnchorData {
        var indexTip: SIMD3<Float>? = nil
        var thumbTip: SIMD3<Float>? = nil
        var wrist: SIMD3<Float>? = nil
        var palm: SIMD3<Float>? = nil
        
        let originMat = anchor.originFromAnchorTransform
        
        if let skeleton = anchor.handSkeleton {
            let indexCol = (originMat * skeleton.joint(.indexFingerTip).anchorFromJointTransform).columns.3
            indexTip = SIMD3<Float>(indexCol.x, indexCol.y, indexCol.z)
            
            let thumbCol = (originMat * skeleton.joint(.thumbTip).anchorFromJointTransform).columns.3
            thumbTip = SIMD3<Float>(thumbCol.x, thumbCol.y, thumbCol.z)
            
            let wristCol = (originMat * skeleton.joint(.wrist).anchorFromJointTransform).columns.3
            wrist = SIMD3<Float>(wristCol.x, wristCol.y, wristCol.z)
            
            let palmCol = (originMat * skeleton.joint(.middleFingerKnuckle).anchorFromJointTransform).columns.3
            palm = SIMD3<Float>(palmCol.x, palmCol.y, palmCol.z)
        }
        
        return HandAnchorData(
            chirality: chirality,
            isTracked: anchor.isTracked,
            handAnchor: anchor,
            indexTipWorldPos: indexTip,
            thumbTipWorldPos: thumbTip,
            wristWorldPos: wrist,
            palmWorldPos: palm,
            originFromAnchorTransform: originMat
        )
    }
}
