import RealityKit
import Cockpit27Domain

public extension CockpitModel {
    @MainActor
    func configureSpatialActuators() {
        print("\n🔧 [SPATIAL] configureSpatialActuators() called")
        
        // Collision groups — bit 2 = hand proxies, bit 3 = cockpit controls.
        // These avoid bit 0 used by makeInteractable()/generateCollisionShapes().
        let handGroup    = CollisionGroup(rawValue: 1 << 2)
        let cockpitGroup = CollisionGroup(rawValue: 1 << 3)
        let controlFilter = CollisionFilter(group: cockpitGroup, mask: handGroup)
        
        // ── Diagnostic: print full entity hierarchy ────────────────────────
        func printHierarchy(_ entity: Entity, indent: String = "  ") {
            let type = (entity as? ModelEntity) != nil ? "ModelEntity" : "Entity"
            var extra = ""
            if let m = entity as? ModelEntity, !m.jointNames.isEmpty {
                extra = " joints=\(m.jointNames)"
            }
            print("\(indent)[\(type)] '\(entity.name)' localPos=\(String(format:"(%.3f,%.3f,%.3f)",entity.position.x,entity.position.y,entity.position.z)) children=\(entity.children.count)\(extra)")
            for child in entity.children { printHierarchy(child, indent: indent + "  ") }
        }
        
        // ── Find the best child to use as a pivot entity ───────────────────
        /// Returns the target ModelEntity to rotate, avoiding empty "_Root" dummy nodes.
        func findPivotChild(of root: Entity) -> Entity? {
            // First pass: recursive search for ModelEntity with joints (skinned mesh)
            var queue: [Entity] = Array(root.children)
            while !queue.isEmpty {
                let current = queue.removeFirst()
                if let m = current as? ModelEntity, !m.jointNames.isEmpty {
                    return m
                }
                queue.append(contentsOf: current.children)
            }
            
            // Second pass: exact name match without "_Rig" (e.g. CP_Lever_Throttle_L inside CP_Lever_Throttle_L_Rig)
            let targetName = root.name.replacingOccurrences(of: "_Rig", with: "")
            if let exactMatch = root.findEntity(named: targetName), exactMatch != root {
                return exactMatch
            }
            
            // Third pass: child with children or ModelComponent (avoiding empty dummy "_Root" nodes)
            for child in root.children {
                if !child.name.lowercased().contains("root") && (!child.children.isEmpty || child.components[ModelComponent.self] != nil) {
                    return child
                }
            }
            
            // Fourth pass: any non-root child
            for child in root.children {
                if !child.name.lowercased().contains("root") {
                    return child
                }
            }
            
            // Fallback: first child
            return root.children.first
        }
        
        // 1.5. MCDU Buttons (Linear Actuator)
        func setupMCDUKeys(in parent: Entity?) {
            guard let parent = parent else { return }
            var count = 0
            var queue: [Entity] = [parent]
            while !queue.isEmpty {
                let current = queue.removeFirst()
                if current.name.lowercased().contains("button") || current.name.lowercased().contains("key") {
                    if current.components[LinearActuatorComponent.self] == nil {
                        current.components.set(LinearActuatorComponent(localAxis: [0, 0, -1], restPosition: current.position, maxTravel: 0.005))
                        count += 1
                    }
                }
                queue.append(contentsOf: current.children)
            }
            print("  📟 MCDU '\(parent.name)': \(count) keys registered")
        }
        setupMCDUKeys(in: self.mcdulParentLeft)
        setupMCDUKeys(in: self.mcdulParentRight)
        
        // 2. Throttles (Arc Lever)
        // baseAxis [1,0,0] = X axis → lever pitches forward/back (correct for throttle)
        let detents: [Float] = [0.0, 0.436, 0.610, 0.785]
        
        if let tL = self.throttleLeft {
            print("  🔍 ThrottleL hierarchy:")
            printHierarchy(tL)
            var comp = LeverComponent(
                pivotOffset: [0, -0.2, 0],
                leverRadius: 0.2,
                sensitivity: 1.0,
                maxAngle: Float.pi / 3,   // 60° max throw
                baseAxis: [1, 0, 0],       // X axis: lever pitches forward/back
                detents: detents
            )
            // Wire the pivot child — the lever arm to rotate in LOCAL space, NOT the root rig
            comp.pivotEntity = findPivotChild(of: tL)
            tL.components.set(comp)
            let worldPos = tL.position(relativeTo: nil)
            print("  ✅ ThrottleL '\(tL.name)' → LeverComponent | worldPos=\(worldPos) | pivotChild='\(comp.pivotEntity?.name ?? "nil")'")
        } else {
            print("  ❌ ThrottleL NOT FOUND — searched for '\(EntityNames.throttleLeft)' and fallback '\(EntityNames.throttleLegacyFallback)'")
        }
        if let tR = self.throttleRight {
            print("  🔍 ThrottleR hierarchy:")
            printHierarchy(tR)
            var comp = LeverComponent(
                pivotOffset: [0, -0.2, 0],
                leverRadius: 0.2,
                sensitivity: 1.0,
                maxAngle: Float.pi / 3,
                baseAxis: [1, 0, 0],
                detents: detents
            )
            comp.pivotEntity = findPivotChild(of: tR)
            tR.components.set(comp)
            let worldPos = tR.position(relativeTo: nil)
            print("  ✅ ThrottleR '\(tR.name)' → LeverComponent | worldPos=\(worldPos) | pivotChild='\(comp.pivotEntity?.name ?? "nil")'")
        } else {
            print("  ❌ ThrottleR NOT FOUND — searched for '\(EntityNames.throttleRight)'")
        }
        
        // 3. Sidestick (Gimbal)
        if let stick = self.sidestick {
            print("  🔍 Sidestick hierarchy:")
            printHierarchy(stick)
            // stickHeight=0.25m → 25cm sweep = full deflection
            var comp = JoystickComponent(maxPitch: 0.35, maxRoll: 0.35, stickRadius: 0.25, sensitivity: 3.5, boneIndex: 1)
            // The pivot is the direct child entity — rotates in local space inside the rig
            comp.pivotEntity = findPivotChild(of: stick)
            
            // Socket & Snap is now calculated purely mathematically in JoystickSystem 
            // using the stick's world position + offset rotated by `combinedQ`.
            
            stick.components.set(comp)
            let worldPos = stick.position(relativeTo: nil)
            print("  ✅ Sidestick '\(stick.name)' → JoystickComponent | worldPos=\(worldPos) | pivotChild='\(comp.pivotEntity?.name ?? "nil")' | socketSnap=READY")
        } else {
            print("  ❌ Sidestick NOT FOUND — searched for '\(EntityNames.sidestick)'")
        }
        
        // 4. Engine Switches (Snapping Switch)
        let engStates: [Float] = [0.0, 0.523]
        if let eng1 = self.engine1Switch {
            eng1.components.set(SnappingSwitchComponent(localRotationAxis: [1, 0, 0], states: engStates))
            print("  ✅ ENG1 switch '\(eng1.name)' registered")
        } else { print("  ❌ ENG1 switch NOT FOUND") }
        if let eng2 = self.engine2Switch {
            eng2.components.set(SnappingSwitchComponent(localRotationAxis: [1, 0, 0], states: engStates))
            print("  ✅ ENG2 switch '\(eng2.name)' registered")
        } else { print("  ❌ ENG2 switch NOT FOUND") }
        
        let modeStates: [Float] = [-0.523, 0.0, 0.523]
        if let modeKnob = self.engineModeKnob {
            modeKnob.components.set(SnappingSwitchComponent(localRotationAxis: [0, 1, 0], states: modeStates))
            print("  ✅ Engine mode knob '\(modeKnob.name)' registered")
        } else { print("  ❌ Engine mode knob NOT FOUND") }
        
        // 5. Fire Fault Buttons
        if let fireL = self.fireFaultButtonLeft {
            fireL.components.set(LinearActuatorComponent(localAxis: [0, -1, 0], restPosition: fireL.position, maxTravel: 0.01))
            print("  ✅ FireFaultL '\(fireL.name)' registered")
        } else { print("  ❌ FireFaultL NOT FOUND") }
        if let fireR = self.fireFaultButtonRight {
            fireR.components.set(LinearActuatorComponent(localAxis: [0, -1, 0], restPosition: fireR.position, maxTravel: 0.01))
            print("  ✅ FireFaultR '\(fireR.name)' registered")
        } else { print("  ❌ FireFaultR NOT FOUND") }
        
        // 6. Pitch Trim Controls
        if let trimKnobL = self.pitchTrimKnobLeft {
            trimKnobL.components.set(RotationalKnobComponent(localRotationAxis: [1, 0, 0], sensitivity: 5.0))
            print("  ✅ PitchTrimKnobL '\(trimKnobL.name)' registered")
        } else { print("  ❌ PitchTrimKnobL NOT FOUND") }
        if let trimKnobR = self.pitchTrimKnobRight {
            trimKnobR.components.set(RotationalKnobComponent(localRotationAxis: [1, 0, 0], sensitivity: 5.0))
            print("  ✅ PitchTrimKnobR '\(trimKnobR.name)' registered")
        } else { print("  ❌ PitchTrimKnobR NOT FOUND") }
        
        let trimWheelStates: [Float] = [-0.5, 0.0, 0.5]
        if let trimWheelL = self.pitchTrimWheelLeft {
            trimWheelL.components.set(SnappingSwitchComponent(localRotationAxis: [1, 0, 0], states: trimWheelStates))
        }
        if let trimWheelR = self.pitchTrimWheelRight {
            trimWheelR.components.set(SnappingSwitchComponent(localRotationAxis: [1, 0, 0], states: trimWheelStates))
        }
        
        print("🔧 [SPATIAL] configureSpatialActuators() complete\n")
    }
}
