import RealityKit
import Foundation

public struct EmissiveButtonComponent: Component {
    public var isOn: Bool = false
    public var isTouching: Bool = false // State: true while finger is touching/pressed on button
    
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
    
    /// Triggers state change when finger presses down on button.
    /// Returns true if press succeeded, or false if finger was already touching.
    @discardableResult
    public mutating func onPressDown() -> Bool {
        guard !isTouching else {
            return false // Already touching - ignore repeated triggers while held
        }
        self.isTouching = true
        self.isOn.toggle()
        self.startEmissiveValue = self.currentEmissiveValue
        self.targetEmissiveValue = self.isOn ? 5.0 : 0.0
        self.isAnimating = true
        self.elapsedTime = 0
        return true
    }
    
    /// Resets state when finger releases / lifts off button.
    public mutating func onRelease() {
        self.isTouching = false
    }
}
