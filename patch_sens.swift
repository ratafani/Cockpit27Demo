import Foundation

let path = "/Volumes/Taftaf Personal/VisionOS Training/Airbus Proj/Cockpit27/Packages/Cockpit27Shared/Sources/Cockpit27Simulation/SpatialInteractionSystem.swift"
var content = try! String(contentsOfFile: path)

content = content.replacingOccurrences(of: "let actualSensitivity = comp.sensitivity * 5.0", with: "let actualSensitivity = comp.sensitivity * 2.5")

try! content.write(toFile: path, atomically: true, encoding: .utf8)
