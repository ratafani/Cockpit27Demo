import RealityKit
import simd

/// Generic Switch Component for toggle switches, rocker switches, and guarded switches
public struct SwitchComponent: Component {
    public var controlID: String
    public var localRotationAxis: SIMD3<Float>
    public var states: [Float] // Angles in radians (e.g. [-0.3, 0.3] for 2-position switch)
    public var currentStateIndex: Int = 0
    public var hysteresisThreshold: Float
    
    // Parent-Child USD hierarchy targets
    public var pivotEntity: Entity?
    public var handleMeshEntity: Entity?
    
    public init(
        controlID: String = "TOGGLE_SWITCH",
        localRotationAxis: SIMD3<Float> = [1, 0, 0],
        states: [Float] = [-0.3, 0.3],
        currentStateIndex: Int = 0,
        hysteresisThreshold: Float = 0.1,
        pivotEntity: Entity? = nil,
        handleMeshEntity: Entity? = nil
    ) {
        self.controlID = controlID
        self.localRotationAxis = localRotationAxis
        self.states = states
        self.currentStateIndex = currentStateIndex
        self.hysteresisThreshold = hysteresisThreshold
        self.pivotEntity = pivotEntity
        self.handleMeshEntity = handleMeshEntity
    }
}
