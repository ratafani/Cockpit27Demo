import RealityKit
import Foundation

public struct EmissiveButtonComponent: Component {
    public var isOn: Bool = false
    public var isTouching: Bool = false // True while index finger tip is inside 3.5cm collision radius
    
    public var currentEmissiveValue: Float = 0.0
    public var startEmissiveValue: Float = 0.0
    public var targetEmissiveValue: Float = 0.0
    
    public var isAnimating: Bool = false
    public var elapsedTime: TimeInterval = 0
    public var duration: TimeInterval = 0.3 // 300ms smooth light toggle animation
    
    // Original rest position of the button entity for physical spring animation
    public var originalPosition: SIMD3<Float>?
    
    // Entities that contain the ModelComponent for material updating
    public var targetEntities: [Entity] = []
    
    public init() {}
}
