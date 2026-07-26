import RealityKit
import simd

public struct RotationalKnobComponent: Component {
    public let localRotationAxis: SIMD3<Float>
    public let sensitivity: Float
    public var currentAngle: Float = 0.0
    public var isGrabbed: Bool = false
    public var activeChirality: Int = -1 // -1 = none, 0 = left, 1 = right
    public var previousHandWorldPosition: SIMD3<Float> = .zero
    public var initialGripOffset: SIMD3<Float>? = nil
    
    public init(localRotationAxis: SIMD3<Float> = [0, 0, 1], sensitivity: Float = 5.0) {
        self.localRotationAxis = localRotationAxis
        self.sensitivity = sensitivity
    }
}
