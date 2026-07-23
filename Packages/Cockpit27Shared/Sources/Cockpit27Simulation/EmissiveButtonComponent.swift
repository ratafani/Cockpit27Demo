import RealityKit
import Foundation

public struct EmissiveButtonComponent: Component {
    public var isOn: Bool = false
    public var currentEmissiveValue: Float = 0.0
    public var startEmissiveValue: Float = 0.0
    public var targetEmissiveValue: Float = 0.0
    
    public var isAnimating: Bool = false
    public var elapsedTime: TimeInterval = 0
    public var duration: TimeInterval = 0.3 // 300ms smooth light toggle animation
    
    // Entities that contain the ModelComponent for material updating
    public var targetEntities: [Entity] = []
    
    public init() {}
    
    public mutating func toggle() {
        self.isOn.toggle()
        self.startEmissiveValue = self.currentEmissiveValue
        self.targetEmissiveValue = self.isOn ? 1.0 : 0.0
        self.isAnimating = true
        self.elapsedTime = 0
    }
}
