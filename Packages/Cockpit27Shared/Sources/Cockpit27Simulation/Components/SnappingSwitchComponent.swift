import RealityKit
import simd

public struct SnappingSwitchComponent: Component {
    public let localRotationAxis: SIMD3<Float>
    public let states: [Float] // Angles in radians
    public var currentStateIndex: Int = 0
    public let hysteresisThreshold: Float
    
    public init(localRotationAxis: SIMD3<Float>, states: [Float], hysteresisThreshold: Float = 0.1) {
        self.localRotationAxis = localRotationAxis
        self.states = states
        self.hysteresisThreshold = hysteresisThreshold
    }
}
