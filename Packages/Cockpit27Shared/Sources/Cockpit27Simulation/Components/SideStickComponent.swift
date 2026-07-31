import RealityKit
import simd

/// Declarative data component representing a 2-DOF SideStick (Captain or First Officer)
public struct SideStickComponent: Component {
    public var controlID: String
    public var maxPitchDegrees: Float
    public var maxRollDegrees: Float
    public var springReturnToCenter: Bool
    public var deadzoneRadius: Float
    
    // Parent-Child USD hierarchy targets
    public var pivotEntity: Entity?
    public var handleMeshEntity: Entity?
    
    // Runtime interaction states
    public var currentPitch: Float = 0.0 // Radians
    public var currentRoll: Float = 0.0  // Radians
    public var isGrabbed: Bool = false
    public var activeChirality: Int = -1 // -1 = None, 0 = Left, 1 = Right
    public var previousHandWorldPosition: SIMD3<Float> = .zero
    public var initialGripOffset: SIMD3<Float>? = nil
    
    // Skeletal animation state
    public var boneIndex: Int = 0
    public var initialBoneRotation: simd_quatf? = nil
    
    // Precise manual grip offset (relative to pivot) for interaction and snapping
    public var handleLocalOffset: SIMD3<Float> = [0, 0.60, 0]
    
    public init(
        controlID: String = "CAPTAIN_SIDESTICK",
        maxPitchDegrees: Float = 20.0,
        maxRollDegrees: Float = 20.0,
        springReturnToCenter: Bool = true,
        deadzoneRadius: Float = 0.02,
        pivotEntity: Entity? = nil,
        handleMeshEntity: Entity? = nil
    ) {
        self.controlID = controlID
        self.maxPitchDegrees = maxPitchDegrees
        self.maxRollDegrees = maxRollDegrees
        self.springReturnToCenter = springReturnToCenter
        self.deadzoneRadius = deadzoneRadius
        self.pivotEntity = pivotEntity
        self.handleMeshEntity = handleMeshEntity
    }
}
