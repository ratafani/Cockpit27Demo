import Foundation

let path = "/Volumes/Taftaf Personal/VisionOS Training/Airbus Proj/Cockpit27/Packages/Cockpit27Shared/Sources/Cockpit27Simulation/CockpitModel+Spatial.swift"
var content = try! String(contentsOfFile: path)

// Fix sidestick sphere -> box
let oldStickBounds = """
            let radius = max(bounds.extents.x, max(bounds.extents.y, bounds.extents.z)) / 2.0
            var stickCollision = CollisionComponent(
                shapes: [ShapeResource.generateSphere(radius: radius).offsetBy(translation: bounds.center)],
                mode: .trigger
            )
"""

let newStickBounds = """
            var stickCollision = CollisionComponent(
                shapes: [ShapeResource.generateBox(size: bounds.extents).offsetBy(translation: bounds.center)],
                mode: .trigger
            )
"""

content = content.replacingOccurrences(of: oldStickBounds, with: newStickBounds)

try! content.write(toFile: path, atomically: true, encoding: .utf8)
