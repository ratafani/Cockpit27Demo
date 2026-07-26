import RealityKit
import simd

public struct LinearActuatorComponent: Component {
    public let localAxis: SIMD3<Float>
    public let restPosition: SIMD3<Float>
    public let maxTravel: Float
    public var isPressed: Bool = false
    public let springStiffness: Float
    
    public init(localAxis: SIMD3<Float>, restPosition: SIMD3<Float>, maxTravel: Float, springStiffness: Float = 50.0) {
        self.localAxis = localAxis
        self.restPosition = restPosition
        self.maxTravel = maxTravel
        self.springStiffness = springStiffness
    }
}
