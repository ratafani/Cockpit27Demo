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
    
    // Cooldown state to prevent rapid double-tapping (on-off-on-off)
    public var lastToggleTime: Date = .distantPast
    public var cooldownDuration: TimeInterval = 0.4 // 400ms cooldown
    
    // Entities that contain the ModelComponent for material updating
    public var targetEntities: [Entity] = []
    
    public init() {}
    
    @discardableResult
    public mutating func toggle() -> Bool {
        let now = Date()
        guard now.timeIntervalSince(lastToggleTime) >= cooldownDuration else {
            return false // Debounced
        }
        self.lastToggleTime = now
        self.isOn.toggle()
        self.startEmissiveValue = self.currentEmissiveValue
        self.targetEmissiveValue = self.isOn ? 5.0 : 0.0 // 0 to 5 range
        self.isAnimating = true
        self.elapsedTime = 0
        return true
    }
}
