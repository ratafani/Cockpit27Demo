import RealityKit
import simd

public struct LeverComponent: Component {
    public let pivotOffset: SIMD3<Float>
    public let leverRadius: Float
    public let sensitivity: Float
    public let maxAngle: Float
    public let baseAxis: SIMD3<Float>
    public let detents: [Float]
    public let detentTolerance: Float
    public var currentAngle: Float = 0.0
    
    public var isGrabbed: Bool = false
    
    public var initialBoneRotation: simd_quatf? = nil
    public var initialEntityRotation: simd_quatf? = nil
    
    // The actual child entity to rotate in LOCAL space (set at setup time)
    public var pivotEntity: Entity?
    
    public var boneIndex: Int
    
    public init(pivotOffset: SIMD3<Float>, leverRadius: Float = 0.15, sensitivity: Float = 1.0,
                maxAngle: Float = Float.pi/2, baseAxis: SIMD3<Float> = [1, 0, 0],
                detents: [Float] = [], detentTolerance: Float = 0.05, boneIndex: Int = 0) {
        self.pivotOffset = pivotOffset
        self.leverRadius = leverRadius
        self.sensitivity = sensitivity
        self.maxAngle = maxAngle
        self.baseAxis = baseAxis
        self.detents = detents
        self.detentTolerance = detentTolerance
        self.boneIndex = boneIndex
    }
}
