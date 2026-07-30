import Foundation
import simd
import ARKit

/// Data structure representing hand skeleton transforms across VisionOS space
public struct HandAnchorData: Sendable {
    public var chirality: Int // 0 = left, 1 = right
    public var isTracked: Bool
    public var handAnchor: HandAnchor?
    public var indexTipWorldPos: SIMD3<Float>?
    public var thumbTipWorldPos: SIMD3<Float>?
    public var wristWorldPos: SIMD3<Float>?
    public var palmWorldPos: SIMD3<Float>?
    public var originFromAnchorTransform: simd_float4x4
    
    public init(
        chirality: Int,
        isTracked: Bool = false,
        handAnchor: HandAnchor? = nil,
        indexTipWorldPos: SIMD3<Float>? = nil,
        thumbTipWorldPos: SIMD3<Float>? = nil,
        wristWorldPos: SIMD3<Float>? = nil,
        palmWorldPos: SIMD3<Float>? = nil,
        originFromAnchorTransform: simd_float4x4 = matrix_identity_float4x4
    ) {
        self.chirality = chirality
        self.isTracked = isTracked
        self.handAnchor = handAnchor
        self.indexTipWorldPos = indexTipWorldPos
        self.thumbTipWorldPos = thumbTipWorldPos
        self.wristWorldPos = wristWorldPos
        self.palmWorldPos = palmWorldPos
        self.originFromAnchorTransform = originFromAnchorTransform
    }
}

/// Protocol for Hand Tracking service abstraction (Cockpit27 specific to prevent module collisions)
@MainActor
public protocol HandTracking27ServiceProtocol: Sendable {
    var latestLeftHand: HandAnchorData? { get }
    var latestRightHand: HandAnchorData? { get }
}

/// Protocol for Spatial Audio / Sound FX trigger abstraction
@MainActor
public protocol Audio27ServiceProtocol: Sendable {
    func playClickSound(controlID: String, position: SIMD3<Float>)
    func playDetentSnapSound(controlID: String, position: SIMD3<Float>)
}

/// Protocol for Telemetry / Cockpit State publishing
@MainActor
public protocol Cockpit27TelemetryProtocol: Sendable {
    func reportControlStateChanged(controlID: String, normalizedValue: Float, stateIndex: Int?)
}

/// Default No-Op implementation for AudioService when no audio engine is attached
@MainActor
public class DefaultAudio27Service: Audio27ServiceProtocol {
    public init() {}
    public func playClickSound(controlID: String, position: SIMD3<Float>) {}
    public func playDetentSnapSound(controlID: String, position: SIMD3<Float>) {}
}

/// Default No-Op implementation for TelemetryService when no engine is attached
@MainActor
public class DefaultCockpit27TelemetryService: Cockpit27TelemetryProtocol {
    public init() {}
    public func reportControlStateChanged(controlID: String, normalizedValue: Float, stateIndex: Int?) {}
}
