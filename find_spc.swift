import RealityKit

func getSkeletalPosesComponent(from entity: Entity) -> (Entity, SkeletalPosesComponent)? {
    if let spc = entity.components[SkeletalPosesComponent.self] {
        return (entity, spc)
    }
    for child in entity.children {
        if let found = getSkeletalPosesComponent(from: child) {
            return found
        }
    }
    return nil
}
