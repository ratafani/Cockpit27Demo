import RealityKit

public struct HandModelComponent: Component {
    public var leftGlove: ModelEntity?
    public var rightGlove: ModelEntity?
    
    // Pinch states
    public var isLeftPinching: Bool = false
    public var isRightPinching: Bool = false
    
    // Pinch world positions
    public var leftPinchPosition: SIMD3<Float> = .zero
    public var rightPinchPosition: SIMD3<Float> = .zero
    
    // Original materials
    public var originalLeftMaterials: [Material] = []
    public var originalRightMaterials: [Material] = []
    
    // Finger status: [Index, Middle, Ring, Little]
    public var leftFingerStatus: [Bool] = [false, false, false, false]
    public var rightFingerStatus: [Bool] = [false, false, false, false]
    
    // Snap target for Left Glove (if set, HandTrackingSystem positions glove here)
    public var leftSnapPosition: SIMD3<Float>?
    public var leftSnapOrientation: simd_quatf?
    
    // Snap target for Right Glove (if set, HandTrackingSystem positions glove here)
    public var rightSnapPosition: SIMD3<Float>?
    public var rightSnapOrientation: simd_quatf?
    
    public init(leftGlove: ModelEntity? = nil, rightGlove: ModelEntity? = nil) {
        self.leftGlove = leftGlove
        self.rightGlove = rightGlove
    }
}
