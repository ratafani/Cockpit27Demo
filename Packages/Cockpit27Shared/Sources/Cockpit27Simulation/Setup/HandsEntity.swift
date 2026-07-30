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
        
        // ── Persistent Hand Joint Colliders (Zero-GC Churn) ─────────────────
        let fingerGroup = CollisionGroup(rawValue: 1 << 2)
        let filter = CollisionFilter(group: fingerGroup, mask: .all)
        
        func createTriggerEntity(name: String, radius: Float = 0.006) -> Entity {
            let e = Entity()
            e.name = name
            let shape = ShapeResource.generateSphere(radius: radius)
            e.components.set(CollisionComponent(shapes: [shape], mode: .trigger, filter: filter))
            return e
        }
        
        let lIndex = createTriggerEntity(name: "LeftIndexCollider")
        let lThumb = createTriggerEntity(name: "LeftThumbCollider")
        let lPalm  = createTriggerEntity(name: "LeftPalmCollider", radius: 0.012)
        
        let rIndex = createTriggerEntity(name: "RightIndexCollider")
        let rThumb = createTriggerEntity(name: "RightThumbCollider")
        let rPalm  = createTriggerEntity(name: "RightPalmCollider", radius: 0.012)
        
        self.addChild(lIndex); self.addChild(lThumb); self.addChild(lPalm)
        self.addChild(rIndex); self.addChild(rThumb); self.addChild(rPalm)
        
        handComponent.leftIndexCollider = lIndex
        handComponent.leftThumbCollider = lThumb
        handComponent.leftPalmCollider  = lPalm
        
        handComponent.rightIndexCollider = rIndex
        handComponent.rightThumbCollider = rThumb
        handComponent.rightPalmCollider  = rPalm
        
        self.components.set(handComponent)
    }
    
    required init() {
        fatalError("init() has not been implemented")
    }
}

