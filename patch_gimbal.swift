import Foundation

let path = "/Volumes/Taftaf Personal/VisionOS Training/Airbus Proj/Cockpit27/Packages/Cockpit27Shared/Sources/Cockpit27Simulation/SpatialInteractionSystem.swift"
var content = try! String(contentsOfFile: path)

// Replace gimbal delta logic
let oldGimbalLogic = """
            if isInteracting, let currentWorld = activeHandPos {
                let parentEntity = entity.parent ?? entity
                let localCurrent  = parentEntity.convert(position: currentWorld, from: nil)
                let localPrevious = prevHandPos != nil
                    ? parentEntity.convert(position: prevHandPos!, from: nil)
                    : localCurrent
                let localDelta = localCurrent - localPrevious

                guard simd_length(localDelta) > 0.0001 else { entity.components.set(comp); continue }

                comp.currentPitch = max(-comp.maxPitch, min(comp.maxPitch,
                    comp.currentPitch + (localDelta.z / comp.stickHeight) * comp.sensitivity))
                comp.currentRoll  = max(-comp.maxRoll,  min(comp.maxRoll,
                    comp.currentRoll  + (localDelta.x / comp.stickHeight) * comp.sensitivity))
"""

let newGimbalLogic = """
            if isInteracting, let currentWorld = activeHandPos {
                let previousWorld = prevHandPos ?? currentWorld
                let worldDelta = currentWorld - previousWorld

                guard simd_length(worldDelta) > 0.0001 else { entity.components.set(comp); continue }

                // In World Space:
                // -Z is Forward (pushing stick forward = negative pitch)
                // +X is Right (pushing stick right = positive roll)
                // Let's amplify sensitivity since the user said it was too weak
                let actualSensitivity = comp.sensitivity * 5.0

                // Pitch: pushing forward (-Z) should pitch forward (usually positive angle around X)
                // We'll subtract worldDelta.z so that moving -Z adds to pitch.
                comp.currentPitch = max(-comp.maxPitch, min(comp.maxPitch,
                    comp.currentPitch - (worldDelta.z / comp.stickHeight) * actualSensitivity))
                
                // Roll: moving right (+X) should roll right. User said left-right was reversed, 
                // so we subtract worldDelta.x instead of adding it, or just ensure the axis matches.
                comp.currentRoll  = max(-comp.maxRoll,  min(comp.maxRoll,
                    comp.currentRoll  - (worldDelta.x / comp.stickHeight) * actualSensitivity))
"""

content = content.replacingOccurrences(of: oldGimbalLogic, with: newGimbalLogic)
try! content.write(toFile: path, atomically: true, encoding: .utf8)
