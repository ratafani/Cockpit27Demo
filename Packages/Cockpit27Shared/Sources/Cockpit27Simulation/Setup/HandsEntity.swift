import RealityKit

public class HandsEntity: Entity {
    
    public var component: HandModelComponent {
        get { components[HandModelComponent.self] ?? HandModelComponent() }
        set { components[HandModelComponent.self] = newValue }
    }
    
    public init(leftGlove: ModelEntity?, rightGlove: ModelEntity?) {
        super.init()
        
        var handComponent = HandModelComponent()
        
        if let left = leftGlove {
            self.addChild(left)
            handComponent.leftGlove = left
            if let mats = left.model?.materials {
                handComponent.originalLeftMaterials = mats
            }
        }
        
        if let right = rightGlove {
            self.addChild(right)
            handComponent.rightGlove = right
            if let mats = right.model?.materials {
                handComponent.originalRightMaterials = mats
            }
        }
        
        self.components.set(handComponent)
    }
    
    required init() {
        fatalError("init() has not been implemented")
    }
}
