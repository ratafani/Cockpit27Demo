import Foundation

let path = "/Volumes/Taftaf Personal/VisionOS Training/Airbus Proj/Cockpit27/Packages/Cockpit27Shared/Sources/Cockpit27Simulation/SpatialComponents.swift"
var content = try! String(contentsOfFile: path)

content = content.replacingOccurrences(of: "public var initialBoneRotation: simd_quatf? = nil", with: "public var initialBoneRotation: simd_quatf? = nil\n    public var initialEntityRotation: simd_quatf? = nil")

try! content.write(toFile: path, atomically: true, encoding: .utf8)
