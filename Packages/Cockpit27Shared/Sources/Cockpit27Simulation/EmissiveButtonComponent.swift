import RealityKit
import Foundation

public struct EmissiveButtonComponent: Component {
    public var isAnimating: Bool = false
    public var elapsedTime: TimeInterval = 0
    public var duration: TimeInterval = 1.0 // 1 second flash
    
    // Entities that contain the ModelComponent for material updating
    public var targetEntities: [Entity] = []
    
    public init() {}
    
    public mutating func startAnimation() {
        self.isAnimating = true
        self.elapsedTime = 0
    }
}
