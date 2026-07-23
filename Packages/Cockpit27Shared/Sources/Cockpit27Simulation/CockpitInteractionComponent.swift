import RealityKit
import simd

public struct CockpitInteractionComponent: Component {
    // Throttle state (independent Left & Right)
    public var throttleLValue: Float = 0.0 // 0.0 to 1.0
    public var throttleRValue: Float = 0.0 // 0.0 to 1.0
    
    public var isThrottleLGrabbed: Bool = false
    public var isThrottleRGrabbed: Bool = false
    
    public var initialThrottleLRotation: simd_quatf?
    public var initialThrottleRRotation: simd_quatf?
    
    public var throttleLValueAtGrabStart: Float = 0.0
    public var throttleRValueAtGrabStart: Float = 0.0
    
    // Entity references
    public var throttleEntity: Entity?      // Left Throttle
    public var throttleRightEntity: Entity? // Right Throttle
    public var sidestickEntity: Entity?
    
    // Sidestick state
    public var sidestickDisplacement: SIMD2<Float> = .zero // -1.0 to 1.0 (x: roll, y: pitch)
    public var isSidestickGrabbed: Bool = false
    public var initialSidestickRotation: simd_quatf?
    public var sidestickModelEntity: ModelEntity?
    public var sidestickJointIndex: Int?
    public var buttonRigEntity: Entity?
    public var initialButtonRigRotation: simd_quatf?
    
    // Pinch positions for deltas
    public var initialLeftPinchPos: SIMD3<Float>?
    public var initialRightPinchPos: SIMD3<Float>?
    
    public init() {}
}
