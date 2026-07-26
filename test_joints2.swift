import Foundation
import RealityKit

func inspect(entity: Entity) {
    if let model = entity as? ModelEntity {
        let names = model.jointNames
        let transforms = model.jointTransforms
        model.jointTransforms = transforms
    }
}
