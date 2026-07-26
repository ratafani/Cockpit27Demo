import Foundation
import RealityKit

func inspect(entity: Entity) {
    if let model = entity as? ModelEntity {
        let names = model.jointNames
        if !names.isEmpty {
            // Is there a property?
            // let transforms = model.jointTransforms
        }
    }
}
