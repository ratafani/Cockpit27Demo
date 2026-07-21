import RealityKit
import simd

public struct CockpitInteractionComponent: Component {
    // Throttle state
    public var throttleValue: Float = 0.0 // 0.0 to 1.0
    public var isThrottleGrabbed: Bool = false
    public var initialThrottleRotation: simd_quatf?
    
    // Sidestick state
    public var sidestickDisplacement: SIMD2<Float> = .zero // -1.0 to 1.0 (x: roll, y: pitch)
    public var isSidestickGrabbed: Bool = false
    public var initialSidestickRotation: simd_quatf?
    
    // Entity references
    public var throttleEntity: Entity?
    public var sidestickEntity: Entity?
    
    // New fields for Joint animation on Sidestick
    public var sidestickModelEntity: ModelEntity?
    public var sidestickJointIndex: Int?
    public var buttonRigEntity: Entity?
    public var initialButtonRigRotation: simd_quatf?
    
    // Pinch positions for deltas
    public var initialLeftPinchPos: SIMD3<Float>?
    public var initialRightPinchPos: SIMD3<Float>?
    public var throttleValueAtGrabStart: Float = 0.0
    
    public init() {}
}
