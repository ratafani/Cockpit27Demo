import RealityKit

public struct HandModelComponent: Component {
    public var leftGlove: ModelEntity?
    public var rightGlove: ModelEntity?
    
    // Pinch states
    public var isLeftPinching: Bool = false
    public var isRightPinching: Bool = false
    
    // Pinch world positions & centroids
    public var leftPinchPosition: SIMD3<Float> = .zero
    public var rightPinchPosition: SIMD3<Float> = .zero
    public var leftPinchCentroid: SIMD3<Float> = .zero
    public var rightPinchCentroid: SIMD3<Float> = .zero
    public var leftPinchDistance: Float = 0.0
    public var rightPinchDistance: Float = 0.0

    
    // Original materials
    public var originalLeftMaterials: [Material] = []
    public var originalRightMaterials: [Material] = []
    
    // Finger status: [Index, Middle, Ring, Little]
    public var leftFingerStatus: [Bool] = [false, false, false, false]
    public var rightFingerStatus: [Bool] = [false, false, false, false]
    
    // Snap target for Left Glove (if set, HandTrackingSystem positions glove here)
    public var leftSnapPosition: SIMD3<Float>?
    public var leftSnapOrientation: simd_quatf?
    public var leftTargetGripPose: String?
    public var leftSnapBlend: Float = 0.0
    
    // Snap target for Right Glove (if set, HandTrackingSystem positions glove here)
    public var rightSnapPosition: SIMD3<Float>?
    public var rightSnapOrientation: simd_quatf?
    public var rightTargetGripPose: String?
    public var rightSnapBlend: Float = 0.0
    
    // Persistent Joint Trigger Colliders (Zero-GC Churn)
    public var leftIndexCollider: Entity?
    public var leftThumbCollider: Entity?
    public var leftPalmCollider: Entity?
    
    public var rightIndexCollider: Entity?
    public var rightThumbCollider: Entity?
    public var rightPalmCollider: Entity?
    
    public init(leftGlove: ModelEntity? = nil, rightGlove: ModelEntity? = nil) {
        self.leftGlove = leftGlove
        self.rightGlove = rightGlove
    }
}

