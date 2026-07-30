import RealityKit
import simd

public enum KnobGestureState: String, Sendable {
    case idle
    case grasped
    case twisting
}

/// Generic Knob Component for rotational controls (dials, rotary selectors, potentiometers)
public struct KnobComponent: Component {
    public var controlID: String
    public var gestureState: KnobGestureState = .idle
    public var localRotationAxis: SIMD3<Float>
    public var sensitivity: Float
    public var currentAngle: Float = 0.0
    public var minAngle: Float
    public var maxAngle: Float
    public var detents: [Float]
    public var detentTolerance: Float
    
    // Parent-Child USD hierarchy targets
    public var pivotEntity: Entity?
    public var handleMeshEntity: Entity?
    
    // Interaction tracking
    public var activeChirality: Int = -1 // -1 = None, 0 = Left, 1 = Right
    public var previousHandAngle: Float = 0.0
    public var knobAngleAtGrasp: Float = 0.0
    
    public init(
        controlID: String = "KNOB_CONTROL",
        localRotationAxis: SIMD3<Float> = [0, 0, 1],
        sensitivity: Float = 3.5,
        minAngle: Float = -.pi,
        maxAngle: Float = .pi,
        detents: [Float] = [],
        detentTolerance: Float = 0.1,
        pivotEntity: Entity? = nil,
        handleMeshEntity: Entity? = nil
    ) {
        self.controlID = controlID
        self.localRotationAxis = localRotationAxis
        self.sensitivity = sensitivity
        self.minAngle = minAngle
        self.maxAngle = maxAngle
        self.detents = detents
        self.detentTolerance = detentTolerance
        self.pivotEntity = pivotEntity
        self.handleMeshEntity = handleMeshEntity
    }
}
