import RealityKit
import simd

public struct JoystickComponent: Component {
    // Mechanical Config
    public let stickRadius: Float
    public let sensitivity: Float
    public let maxPitch: Float
    public let maxRoll: Float
    public let springCenteringRatio: Float
    
    // Calculated State
    public var currentPitch: Float = 0.0
    public var currentRoll: Float = 0.0
    
    // Sticky Grip State
    public var isLocked: Bool = false
    public var previousHandWorldPosition: SIMD3<Float> = .zero
    public var initialGripOffset: SIMD3<Float>? = nil
    public var isHandInsideCollider: Bool = false 
    
    // Animation state
    public var initialBoneRotation: simd_quatf? = nil
    public var initialEntityRotation: simd_quatf? = nil
    public var pivotEntity: Entity?
    public var boneIndex: Int
    
    // Socket & Snap (Calculated Mathematically in World Space)
    
    // Which hand is gripping: -1=none, 0=left, 1=right
    public var activeChirality: Int = -1
    
    public init(maxPitch: Float, maxRoll: Float, stickRadius: Float = 0.20,
                sensitivity: Float = 1.2, springCenteringRatio: Float = 0.20, boneIndex: Int = 0) {
        self.maxPitch = maxPitch
        self.maxRoll = maxRoll
        self.stickRadius = stickRadius
        self.sensitivity = sensitivity
        self.springCenteringRatio = springCenteringRatio
        self.boneIndex = boneIndex
    }
}
