import Foundation

let path = "/Volumes/Taftaf Personal/VisionOS Training/Airbus Proj/Cockpit27/Packages/Cockpit27Shared/Sources/Cockpit27Simulation/SpatialInteractionSystem.swift"
var content = try! String(contentsOfFile: path)

content = content.replacingOccurrences(of: "comp.currentRoll  + (worldDelta.x / comp.stickHeight) * actualSensitivity", with: "comp.currentRoll  - (worldDelta.x / comp.stickHeight) * actualSensitivity")

try! content.write(toFile: path, atomically: true, encoding: .utf8)
