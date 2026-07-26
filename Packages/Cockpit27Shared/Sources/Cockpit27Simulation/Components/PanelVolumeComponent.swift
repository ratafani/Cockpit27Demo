import RealityKit
import simd

public struct PanelVolumeComponent: Component {
    public var isActive: Bool = false
    public let boundingBox: BoundingBox
    
    public init(boundingBox: BoundingBox) {
        self.boundingBox = boundingBox
    }
}
