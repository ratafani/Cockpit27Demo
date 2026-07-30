import RealityKit
import simd

@MainActor
public func isPointInsideEntity(_ worldPoint: SIMD3<Float>, entity: Entity, padding: Float = 0.005) -> Bool {
    let inv = simd_inverse(entity.transformMatrix(relativeTo: nil))
    let local4 = simd_mul(inv, SIMD4<Float>(worldPoint, 1.0))
    let p = SIMD3<Float>(local4.x, local4.y, local4.z) / local4.w
    let bounds = entity.visualBounds(relativeTo: entity)
    let halfSize = max(bounds.extents / 2.0, SIMD3<Float>(0.01, 0.01, 0.01)) + SIMD3<Float>(repeating: padding)
    let center = bounds.center
    return abs(p.x - center.x) <= halfSize.x &&
           abs(p.y - center.y) <= halfSize.y &&
           abs(p.z - center.z) <= halfSize.z
}
