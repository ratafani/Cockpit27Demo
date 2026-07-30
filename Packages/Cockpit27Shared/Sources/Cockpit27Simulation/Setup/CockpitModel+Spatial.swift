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
        _ = CollisionFilter(group: cockpitGroup, mask: handGroup)
        
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
        
        // ── Helper: Attach Submesh Trigger Collision ──────────────────────
        func attachSubmeshTrigger(to entity: Entity, isSmallButton: Bool = false) {
            let filter = CollisionFilter(group: cockpitGroup, mask: handGroup)
            let target = findPivotChild(of: entity) ?? entity
            if let model = target as? ModelEntity, let mesh = model.model?.mesh {
                let shape = ShapeResource.generateConvex(from: mesh)
                target.components.set(CollisionComponent(shapes: [shape], mode: .trigger, filter: filter))
            } else {
                let bounds = entity.visualBounds(relativeTo: entity)
                let extents = isSmallButton ? SIMD3<Float>(0.015, 0.015, 0.012) : max(bounds.extents, [0.02, 0.02, 0.02])
                let shape = ShapeResource.generateBox(size: extents)
                target.components.set(CollisionComponent(shapes: [shape], mode: .trigger, filter: filter))
            }
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
                        attachSubmeshTrigger(to: current, isSmallButton: true)
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
        let detents: [Float] = [0.0, 0.436, 0.610, 0.785]
        
        if let tL = self.throttleLeft {
            var comp = LeverComponent(
                pivotOffset: [0, -0.2, 0],
                leverRadius: 0.2,
                sensitivity: 1.0,
                maxAngle: Float.pi / 3,   // 60° max throw
                baseAxis: [1, 0, 0],       // X axis: lever pitches forward/back
                detents: detents
            )
            comp.pivotEntity = tL
            comp.handleMeshEntity = findPivotChild(of: tL)
            tL.components.set(comp)
            attachSubmeshTrigger(to: comp.handleMeshEntity ?? tL)
            print("  ✅ ThrottleL '\(tL.name)' → LeverComponent & SubmeshTrigger attached")
        }
        if let tR = self.throttleRight {
            var comp = LeverComponent(
                pivotOffset: [0, -0.2, 0],
                leverRadius: 0.2,
                sensitivity: 1.0,
                maxAngle: Float.pi / 3,
                baseAxis: [1, 0, 0],
                detents: detents
            )
            comp.pivotEntity = tR
            comp.handleMeshEntity = findPivotChild(of: tR)
            tR.components.set(comp)
            attachSubmeshTrigger(to: comp.handleMeshEntity ?? tR)
            print("  ✅ ThrottleR '\(tR.name)' → LeverComponent & SubmeshTrigger attached")
        }
        
        if let stick = self.sidestick {
            var comp = SideStickComponent(controlID: "CAPT_SIDESTICK", maxPitchDegrees: 20.0, maxRollDegrees: 20.0)
            comp.boneIndex = 1 // Use bone index 1 for the stick shaft (0 is usually the root/base)
            comp.pivotEntity = findPivotChild(of: stick)
            comp.handleMeshEntity = comp.pivotEntity
            stick.components.set(comp)
            attachSubmeshTrigger(to: comp.handleMeshEntity ?? stick)
            print("  ✅ Sidestick '\(stick.name)' → SideStickComponent & SubmeshTrigger attached")
        }
        
        // 4. Engine Switches (Switch)
        let engStates: [Float] = [0.0, 0.523]
        if let eng1 = self.engine1Switch {
            eng1.components.set(SwitchComponent(controlID: "ENG_1_MASTER", localRotationAxis: [1, 0, 0], states: engStates))
            attachSubmeshTrigger(to: eng1, isSmallButton: true)
            print("  ✅ ENG1 switch '\(eng1.name)' registered with SubmeshTrigger")
        }
        if let eng2 = self.engine2Switch {
            eng2.components.set(SwitchComponent(controlID: "ENG_2_MASTER", localRotationAxis: [1, 0, 0], states: engStates))
            attachSubmeshTrigger(to: eng2, isSmallButton: true)
            print("  ✅ ENG2 switch '\(eng2.name)' registered with SubmeshTrigger")
        }
        
        let modeStates: [Float] = [-0.523, 0.0, 0.523]
        if let modeKnob = self.engineModeKnob {
            var comp = KnobComponent(controlID: "ENG_MODE_SEL", localRotationAxis: [0, 0, 1], sensitivity: 3.0, detents: modeStates, detentTolerance: 0.1)
            comp.handleMeshEntity = findPivotChild(of: modeKnob)
            modeKnob.components.set(comp)
            attachSubmeshTrigger(to: comp.handleMeshEntity ?? modeKnob)
            print("  ✅ Engine mode knob '\(modeKnob.name)' registered with SubmeshTrigger")
        }
        
        // 5. Fire Fault Buttons
        if let fireL = self.fireFaultButtonLeft {
            fireL.components.set(LinearActuatorComponent(localAxis: [0, -1, 0], restPosition: fireL.position, maxTravel: 0.01))
            attachSubmeshTrigger(to: fireL, isSmallButton: true)
            print("  ✅ FireFaultL '\(fireL.name)' registered")
        }
        if let fireR = self.fireFaultButtonRight {
            fireR.components.set(LinearActuatorComponent(localAxis: [0, -1, 0], restPosition: fireR.position, maxTravel: 0.01))
            attachSubmeshTrigger(to: fireR, isSmallButton: true)
            print("  ✅ FireFaultR '\(fireR.name)' registered")
        }
        
        print("🔧 [SPATIAL] configureSpatialActuators() complete\n")
    }
}

