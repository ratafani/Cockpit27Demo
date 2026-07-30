import RealityKit
import simd

public struct KnobGestureMath {
    /// Compute the midpoint (centroid) and 3D Euclidean distance between thumb and index tips.
    public static func computePinchCentroidAndDistance(thumb: SIMD3<Float>, index: SIMD3<Float>) -> (centroid: SIMD3<Float>, distance: Float) {
        let centroid = (thumb + index) * 0.5
        let distance = simd_distance(thumb, index)
        return (centroid, distance)
    }
    
    /// Compute polar angle in local space around the knob's rotation plane.
    public static func computePolarAngleInLocalPlane(localPoint: SIMD3<Float>, rotationAxis: SIMD3<Float>) -> Float {
        if abs(rotationAxis.z) > 0.5 {
            // Rotation around Z -> local plane is XY
            return atan2(localPoint.y, localPoint.x)
        } else if abs(rotationAxis.y) > 0.5 {
            // Rotation around Y -> local plane is XZ
            return atan2(localPoint.z, localPoint.x)
        } else {
            // Rotation around X -> local plane is YZ
            return atan2(localPoint.z, localPoint.y)
        }
    }
    
    /// Compute planar radius of a local point from the knob axis origin.
    public static func computePlanarRadius(localPoint: SIMD3<Float>, rotationAxis: SIMD3<Float>) -> Float {
        if abs(rotationAxis.z) > 0.5 {
            return simd_length(SIMD2<Float>(localPoint.x, localPoint.y))
        } else if abs(rotationAxis.y) > 0.5 {
            return simd_length(SIMD2<Float>(localPoint.x, localPoint.z))
        } else {
            return simd_length(SIMD2<Float>(localPoint.y, localPoint.z))
        }
    }
    
    /// Normalize angle delta to [-π, +π] wrap-around range.
    public static func normalizeAngleDelta(_ delta: Float) -> Float {
        var d = delta
        while d > Float.pi { d -= Float.pi * 2 }
        while d < -Float.pi { d += Float.pi * 2 }
        return d
    }
    
    /// Non-linear dead zone power curve: pow(|delta| - deadzone, exponent) * sign(delta).
    public static func applyDeadzonePowerCurve(delta: Float, deadzone: Float = 0.02, exponent: Float = 1.3) -> Float {
        let absDelta = abs(delta)
        guard absDelta > deadzone else { return 0.0 }
        let effective = absDelta - deadzone
        let curved = pow(effective, exponent)
        return delta >= 0 ? curved : -curved
    }
    
    /// Find the closest detent angle if within tolerance threshold.
    public static func findClosestDetent(angle: Float, detents: [Float], tolerance: Float) -> Float? {
        guard !detents.isEmpty else { return nil }
        var closest = angle
        var minDiff: Float = .greatestFiniteMagnitude
        for detent in detents {
            let diff = abs(angle - detent)
            if diff < minDiff {
                minDiff = diff
                closest = detent
            }
        }
        return minDiff <= tolerance ? closest : nil
    }
}
