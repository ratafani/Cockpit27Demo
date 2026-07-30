# Cockpit27: Detailed Technical Analysis of Hand Collision, Gesture Interaction & Trigger Mechanics

## 1. Executive Summary

This document provides a comprehensive technical audit of the **Cockpit27** VisionOS codebase, focusing on **ARKit Hand Tracking**, **Entity Interaction Systems**, **Gesture State Machines**, **Collision Trigger Areas**, and **Control Movement Kinematics**.

Currently, Cockpit27 relies primarily on **manual 3D bounding box checks (`visualBounds`)** and **fixed spherical distance thresholds** (ranging from 3.5 cm to 10 cm radii) rather than native RealityKit mesh physics colliders. In a dense cockpit environment (such as the Flight Control Unit or Overhead Panel), these broad distance radii cause **trigger area overlaps**, leading to accidental activations of adjacent switches, knobs, and buttons.

---

## 2. Architecture Overview & System Mapping

Cockpit27 uses a custom **RealityKit Entity-Component-System (ECS)** combined with **ARKit Hand Tracking** (`ILSHandTracking` service). Hand anchors are fetched directly in system `update(context:)` loops, and joint transformations are projected into world space.

### Core Component & System Files

| Subsystem | Component File | System File | Interaction Type | Trigger Criterion |
| :--- | :--- | :--- | :--- | :--- |
| **Hand Tracking** | `HandModelComponent.swift` | `HandTrackingSystem.swift` | Bone alignment & Snap target positioning | ARKit `HandSkeleton` joint transforms |
| **Joystick / Sidestick** | `JoystickComponent.swift` | `JoystickSystem.swift` | Power Grip & 2D Vector Tilt (Pitch/Roll) | 10 cm Palm Sphere (`simd_distance <= 0.10m`) |
| **Thrust / Flap Levers** | `LeverComponent.swift` | `LeverSystem.swift` | Power Grip & 1D Rotation along Base Axis | 10 cm Palm Sphere (`simd_distance <= 0.10m`) |
| **Rotational Knobs** | `RotationalKnobComponent.swift` | `RotationalKnobSystem.swift` | Pinch Gesture & Rotary Drag | 10 cm Tip Sphere (`simd_distance <= 0.10m`) |
| **Push Buttons** | `EmissiveButtonComponent.swift` | `EmissiveButtonSystem.swift` | Direct Touch Press & Emissive Animation | 3.5 cm Tip Sphere (`simd_distance < 0.035m`) |
| **Linear Actuators** | `LinearActuatorComponent.swift` | `LinearActuatorSystem.swift` | Push-Pull Linear Axis Travel | `visualBounds` AABB + 5 cm expansion box |
| **Snapping Switches** | `SnappingSwitchComponent.swift` | `SnappingSwitchSystem.swift` | Multi-state Rotary Angle Snap | `visualBounds` AABB + 5 cm expansion box |

---

## 3. Deep Dive into System Implementations

### 3.1 Hand Tracking (`HandTrackingSystem.swift`)
- **Location**: `Packages/Cockpit27Shared/Sources/Cockpit27Simulation/Systems/HandTrackingSystem.swift`
- **Mechanism**:
  - Queries `HandModelComponent` entities.
  - Retrieves `latestLeftHand` and `latestRightHand` from `CockpitHandTracking.currentService`.
  - Applies ARKit `HandSkeleton` joint rotations to the 3D glove `ModelEntity` (`jointTransforms[index].rotation`).
  - **Gesture Detection**: Evaluates finger curling by comparing tip-to-wrist distance versus knuckle-to-wrist distance:
    $$\text{isCurled} = \text{distance}(\text{tip}, \text{wrist}) < \text{distance}(\text{knuckle}, \text{wrist})$$
  - Triggers global `isPinching` state if $\ge 3$ fingers are curled.
  - Position output: Sets `pinchPos` to middle finger knuckle column in world space.

### 3.2 Sidestick (`JoystickSystem.swift`)
- **Location**: `Packages/Cockpit27Shared/Sources/Cockpit27Simulation/Systems/JoystickSystem.swift`
- **Proximity & Trigger Logic**:
  - Determines handle position: `handleWorldPos = meshEntity.visualBounds(relativeTo: nil).center`.
  - Checks palm proximity: `simd_distance(palm, handleWorldPos) <= 0.10` (10 cm sphere).
- **Grip Evaluation (`evaluateGripState`)**:
  - Evaluates pinch ($\text{distance}(\text{thumb}, \text{index/middle/ring}) < 4.5\text{ cm}$) OR power grip ($\ge 3$ curled fingers AND $\text{thumb-to-middle} \le 5\text{ cm}$).
  - Requires `isPalmNearHandle` ($10\text{ cm}$) to engage.
  - Release threshold (hysteresis): `simd_distance(palm, handleWorldPos) > 0.45` (45 cm radius).
- **Kinematics**:
  - Converts world Z movement to Pitch and world X movement to Roll.
  - Applies bone transform updates to animated USDZ sidestick joint.

### 3.3 Levers (`LeverSystem.swift`)
- **Location**: `Packages/Cockpit27Shared/Sources/Cockpit27Simulation/Systems/LeverSystem.swift`
- **Proximity & Trigger Logic**:
  - Lever handle position: `meshEntity.visualBounds(relativeTo: nil).center`.
  - Trigger radius: `0.10m` (10 cm sphere around handle center).
  - Release radius: `0.45m` (45 cm hysteresis).
- **Grip Evaluation**:
  - Same biomechanical logic as `JoystickSystem` (Pinch or Power Grip + 10 cm proximity).

### 3.4 Rotational Knobs (`RotationalKnobSystem.swift`)
- **Location**: `Packages/Cockpit27Shared/Sources/Cockpit27Simulation/Systems/RotationalKnobSystem.swift`
- **Proximity & Trigger Logic**:
  - Uses index finger tip position.
  - Proximity threshold: `simd_distance(tip, visualBounds.center) < 0.10` (10 cm radius sphere).
- **Gesture State**:
  - Requires thumb-to-finger tip distance $< 2.5\text{ cm}$ (0.025m) to grab.
  - Releases when thumb-to-finger distance $> 5.0\text{ cm}$.

### 3.5 Emissive Push Buttons (`EmissiveButtonSystem.swift`)
- **Location**: `Packages/Cockpit27Shared/Sources/Cockpit27Simulation/Systems/EmissiveButtonSystem.swift`
- **Proximity & Trigger Logic**:
  - Finger tip distance to `entity.visualBounds(relativeTo: nil).center`.
  - Touch threshold: `minDist < 0.035` (3.5 cm radius = 7 cm total sphere diameter).
- **Action**:
  - Triggers press state, depresses button entity 1 cm inward, and ramps material emissive luminance to `5.0`.

### 3.6 Linear Actuators & Snapping Switches (`LinearActuatorSystem.swift`, `SnappingSwitchSystem.swift`)
- **Location**: `LinearActuatorSystem.swift`, `SnappingSwitchSystem.swift`
- **Proximity & Trigger Logic**:
  - Obtains `entity.visualBounds(relativeTo: nil)`.
  - Expands bounding box by 5 cm on all axes: `BoundingBox(min: box.min - 0.05, max: box.max + 0.05)`.
  - Checks if index tip position falls inside `expandBox`.

---

## 4. Root Cause Analysis: Why Trigger Areas Are Too Large

```
                       CURRENT APPROACH (Spherical / Expanded Bounds)
                       
              ┌─────────────────────────────────────────────────┐
              │           10cm Sphere / 5cm Expanded Box        │
              │                                                 │
              │         ┌───────────┐     ┌───────────┐         │
              │         │  Knob A   │     │  Knob B   │         │
              │         └───────────┘     └───────────┘         │
              │                ▲                 ▲              │
              └────────────────┼─────────────────┼──────────────┘
                               │                 │
                    Finger inside trigger zone of BOTH knobs!
```

1. **Fixed Spherical Radii Overlap Clustered Controls**:
   - Small buttons ($1.5\text{ cm} \times 1.5\text{ cm}$) use a $3.5\text{ cm}$ radius sphere ($7\text{ cm}$ diameter). When buttons are spaced $2\text{ cm}$ apart on an FCU, a single finger tip activates multiple adjacent buttons simultaneously.
   - Rotational knobs ($2\text{ cm}$ diameter) use a $10\text{ cm}$ radius sphere, creating a $20\text{ cm}$ active zone.

2. **Unscaled / Offset `visualBounds.center`**:
   - `visualBounds` calculates axis-aligned bounding boxes (AABB) in world space across all submeshes. If a model includes pivot hierarchy transforms or root offsets, `center` does not align with the physical user-facing knob cap or button face.

3. **Expanded Bounding Boxes (+5 cm)**:
   - Expanding bounding boxes by $5\text{ cm}$ (`box.min - 0.05`, `box.max + 0.05`) turns a $2\text{ cm}$ switch into a $12\text{ cm}$ trigger volume.

4. **Absence of Mesh-Level Collision Shapes**:
   - None of the entities currently attach RealityKit `CollisionComponent` or `ShapeResource` instances. All checks are manual floating-point point-to-point vector distances.

---

## 5. Solutions & Technical Approaches

### Approach A: Native RealityKit `CollisionComponent` + Hand Skeleton Collider Entities (Recommended)

Utilize RealityKit's native physics and collision engine instead of custom distance formulas.

```
                    PROPOSED APPROACH (Native Collision Shapes)
                    
                   ┌───────────┐           ┌───────────┐
                   │  Knob A   │           │  Knob B   │
                   │ (Collider)│           │ (Collider)│
                   └───────────┘           └───────────┘
                         ▲
                         │
                  [Finger Sphere]  <-- Collides ONLY with Knob A
```

#### 1. Setup Control Colliders:
Attach tight, precise collision shapes during entity initialization or scene loading:
```swift
// Option A: Tight Box Shape matching exact physical geometry
let boxShape = ShapeResource.generateBox(size: SIMD3<Float>(0.02, 0.02, 0.015)) // 2cm x 2cm x 1.5cm
entity.components.set(CollisionComponent(shapes: [boxShape]))

// Option B: Convex Mesh Shape generated directly from USDZ model mesh
if let modelMesh = entity.components[ModelComponent.self]?.mesh {
    ShapeResource.generateConvex(from: modelMesh).then { convexShape in
        entity.components.set(CollisionComponent(shapes: [convexShape]))
    }
}
```

#### 2. Setup Hand Joint Colliders:
In `HandTrackingSystem.swift`, attach small invisible `CollisionComponent` entities (e.g. 8 mm radius sphere) to index finger tip, thumb tip, and palm:
```swift
let fingerTipCollider = Entity()
fingerTipCollider.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.008)]))
```

#### 3. Perform Collision Evaluation:
Inside your simulation systems (`EmissiveButtonSystem`, `RotationalKnobSystem`, etc.):
```swift
let collidingEntities = context.scene.collidingEntities(containing: fingerTipCollider)
let isTouchingThisItem = collidingEntities.contains(entity)
```

---

### Approach B: Oriented Bounding Box (OBB) Local Space Point Test (Lightweight Math Solution)

Transform hand joint coordinates into the entity's **local coordinate space** to perform oriented box intersection tests.

```swift
// Convert world finger position to local entity space
let worldToLocal = entity.transformMatrix(relativeTo: nil).inverse
let localFingerPos4 = simd_mul(worldToLocal, SIMD4<Float>(worldFingerPos, 1.0))
let localFingerPos = SIMD3<Float>(localFingerPos4.x, localFingerPos4.y, localFingerPos4.z) / localFingerPos4.w

// Test against tight local extents (e.g. 1.5cm button + 0.5cm padding margin)
let halfSize = comp.localDimensions / 2.0 + SIMD3<Float>(0.005, 0.005, 0.005)
let isInsideOBB = abs(localFingerPos.x) <= halfSize.x &&
                  abs(localFingerPos.y) <= halfSize.y &&
                  abs(localFingerPos.z) <= halfSize.z
```

---

### Approach C: RealityKit Raycasting & Convex Casting

For direct finger-touch interactions (buttons, switches):

```swift
let rayOrigin = indexTipPosition
let rayDirection = indexTipForwardVector

// Cast short 2cm ray from index tip
let hits = context.scene.raycast(from: rayOrigin, to: rayOrigin + rayDirection * 0.02)
if let closestHit = hits.first, closestHit.entity == buttonEntity {
    // Touch confirmed exclusively on targeted button
}
```

---

## 6. System Refactoring Comparison Matrix

| Approach | Implementation Complexity | Spatial Precision | Performance Impact | Best Suited For |
| :--- | :--- | :--- | :--- | :--- |
| **Current (Global Radii)** | Low (Existing) | Low ($3.5-10\text{ cm}$ spheres) | Low | Isolated controls |
| **Approach A (RealityKit Collision)** | Medium | Very High (Exact mesh geometry) | Low (Handled by RealityKit) | Sidesticks, Levers, Complex Knobs |
| **Approach B (Local OBB Bounds)** | Low-Medium | High (Tight oriented box) | Minimal (Simple Matrix Math) | Flat Panel Buttons, Multi-switches |
| **Approach C (Raycasting)** | Medium | High (Directional touch) | Low | Direct push buttons |

---

## 7. Control Kinematics & Movement Approaches (How Each Control Moves)

This section details the physical motion mechanics, vector mathematics, constraint solvers, and glove snapping methods for each cockpit control type in **Cockpit27**.

### 7.1 Sidestick Movement (2-DOF Spherical Pivot & Delta Kinematics)

```
                            [ Hand Movement ]
                                   │
                    ┌──────────────┴──────────────┐
                    ▼                             ▼
             World Z Delta                 World X Delta
                    │                             │
                    ▼                             ▼
             Pitch Angle (θ)               Roll Angle (ϕ)
                    │                             │
                    └──────────────┬──────────────┘
                                   ▼
                      Combined Rotation Quaternion
                       Q = quat(θ, X) * quat(-ϕ, Z)
                                   │
                    ┌──────────────┴──────────────┐
                    ▼                             ▼
           Update USDZ Bone Joint          Snap 3D Glove Socket
```

1. **State & Grip Lock**:
   - When Power Grip + 10 cm handle proximity is detected, store the initial wrist position relative to stick base:
     $$\mathbf{O}_{grip} = \mathbf{R}_{tilted}^{-1} \cdot (\mathbf{P}_{wrist} - \mathbf{P}_{stickBase})$$
   - Lock hand to stick (`isLocked = true`).

2. **World-Space Vector Delta Calculation**:
   Calculate hand position displacement between frames:
   $$\Delta \mathbf{P} = \mathbf{P}_{hand, current} - \mathbf{P}_{hand, previous}$$
   - **Pitch Delta**: Hand moving forward ($-\mathbf{Z}$) tilts stick forward (negative pitch angle):
     $$\Delta \theta_{pitch} = \left(\frac{\Delta P_z}{R_{stick}}\right) \cdot S_{sensitivity}$$
   - **Roll Delta**: Hand moving right ($+\mathbf{X}$) rolls stick right (positive roll angle):
     $$\Delta \theta_{roll} = \left(\frac{\Delta P_x}{R_{stick}}\right) \cdot S_{sensitivity}$$

3. **Angular Range Clamping & Quaternions**:
   $$\theta_{pitch} = \text{clamp}(\theta_{pitch} + \Delta \theta_{pitch}, -\theta_{max}, \theta_{max})$$
   $$\theta_{roll} = \text{clamp}(\theta_{roll} + \Delta \theta_{roll}, -\phi_{max}, \phi_{max})$$
   $$\mathbf{Q}_{pitch} = \text{simd\_quatf}(\text{angle}: \theta_{pitch}, \text{axis}: [1, 0, 0])$$
   $$\mathbf{Q}_{roll} = \text{simd\_quatf}(\text{angle}: -\theta_{roll}, \text{axis}: [0, 0, 1])$$
   $$\mathbf{Q}_{combined} = \mathbf{Q}_{pitch} \times \mathbf{Q}_{roll}$$

4. **Bone Rotation Application**:
   Apply quaternion to the USDZ armature joint:
   $$\mathbf{Q}_{joint, new} = \mathbf{Q}_{combined} \times \mathbf{Q}_{joint, initial}$$

5. **3D Glove Socket Snapping**:
   Compute the exact socket position in world space so the user's virtual hand glove remains visually clamped to the stick grip during tilt:
   $$\mathbf{P}_{socket} = \mathbf{P}_{stickBase} + (\mathbf{Q}_{combined} \times \mathbf{Q}_{stickWorld}) \cdot \mathbf{O}_{grip}$$
   Set `handComp.rightSnapPosition = socketPos`.

6. **Spring Centering on Release**:
   When hand releases power grip:
   $$\theta_{pitch} \leftarrow \theta_{pitch} - \theta_{pitch} \cdot r_{centering}$$
   $$\theta_{roll} \leftarrow \theta_{roll} - \theta_{roll} \cdot r_{centering}$$

---

### 7.2 Throttle / Lever Movement (1-DOF Arc Rotation & Detent Magnetism)

```
                            [ Hand Displacement ]
                                      │
                                      ▼
                        Linear Motion along Axis (L)
                        L = -ΔP.z + 0.5 * ΔP.y
                                      │
                                      ▼
                           Angular Delta (Δθ)
                           Δθ = (L / R) * Sensitivity
                                      │
                                      ▼
                           Detent Tolerance Check
                   ┌──────────────────┴──────────────────┐
                   ▼                                     ▼
        Inside Magnet Tolerance                Outside Tolerance
        Snap θ to Detent Angle                 Apply Raw Angle θ
```

1. **Arc Motion Calculation**:
   Lever moves strictly around 1-DOF pivot base axis $\mathbf{A}_{base}$ (typically $[1, 0, 0]$):
   $$\Delta L = -\Delta P_z + 0.5 \cdot \Delta P_y$$
   $$\Delta \theta = \left(\frac{\Delta L}{R_{lever}}\right) \cdot S_{sensitivity}$$
   $$\theta_{target} = \text{clamp}(\theta_{current} + \Delta \theta, 0, \theta_{max})$$

2. **Soft Detent Magnetic Pull (In-Flight Magnetism)**:
   While dragging near a detent notch (IDLE, CLIMB, FLEX, TOGA):
   $$\text{if } |\theta_{target} - \theta_{detent}| < 0.5 \cdot \text{tolerance} \implies \theta_{target} = \theta_{detent}$$

3. **Hard Detent Snap (On Release)**:
   Upon hand release, snap to the nearest detent if within `detentTolerance`:
   $$\theta_{final} = \text{nearestDetent}(\theta_{current}, \text{tolerance})$$

4. **USDZ Bone / Entity Transformation**:
   $$\mathbf{Q}_{lever} = \text{simd\_quatf}(\text{angle}: \theta, \text{axis}: \mathbf{A}_{base})$$
   $$\mathbf{Q}_{model} = \mathbf{Q}_{lever} \times \mathbf{Q}_{initial}$$

5. **Lever Top Handle Socket Position**:
   Extract live bone position matrix from USDZ skeleton or transform socket offset:
   $$\mathbf{P}_{socket} = \mathbf{P}_{pivot} + (\mathbf{Q}_{baseWorld} \times \mathbf{Q}_{lever}) \cdot \mathbf{O}_{grip}$$

---

### 7.3 Rotational Knob Movement (Pinch & Angular Drag Tracking)

```
                          [ Hand Pinch Detected ]
                                     │
                 ┌───────────────────┴───────────────────┐
                 ▼                                       ▼
    Approach A: Tangential Drag             Approach B: Polar Angle
   Δθ = LocalDelta.x * Sensitivity         θ = atan2(LocalY, LocalX)
                                           Δθ = θ_current - θ_previous
                 │                                       │
                 └───────────────────┬───────────────────┘
                                     ▼
                        Rotation Quaternion Update
                           Q = quat(θ, Axis)
                                     │
                                     ▼
                          Detent Step Snapping
```

1. **Pinch Activation**:
   Requires index-to-thumb tip distance $< 2.5\text{ cm}$.

2. **Angular Update Methods**:
   - **Method A: Local Tangential Drag (Current)**:
     Convert world hand displacement into local parent entity space:
     $$\Delta \mathbf{P}_{local} = \mathbf{M}_{parent}^{-1} \cdot \mathbf{P}_{tip, curr} - \mathbf{M}_{parent}^{-1} \cdot \mathbf{P}_{tip, prev}$$
     $$\Delta \theta = \Delta P_{local, x} \cdot S_{sensitivity}$$
   - **Method B: Polar Arc Rotation (Recommended for Precise Tuning)**:
     Calculate finger position angle in knob local plane:
     $$\theta_{hand} = \text{atan2}(P_{local, y}, P_{local, x})$$
     $$\Delta \theta = \theta_{hand, current} - \theta_{hand, previous}$$

3. **Rotation Application**:
   $$\mathbf{Q}_{knob} = \text{simd\_quatf}(\text{angle}: \theta_{current}, \text{axis}: \mathbf{A}_{rotation})$$
   Apply $\mathbf{Q}_{knob} \times \mathbf{Q}_{initial}$ to bone joint transform or entity orientation.

4. **Discrete Step Detent Snapping**:
   On release, snap to discrete steps (e.g., 1000 ft or 100 ft increments for FCU Altitude Knob):
   $$\theta_{snapped} = \text{round}\left(\frac{\theta}{\theta_{step}}\right) \cdot \theta_{step}$$

---

### 7.4 Push Button Movement (1-DOF Depress, Latching & Emissive State)

```
                         [ Index Tip Touches Button ]
                                     │
                                     ▼
                        Depress Mesh Inward (1cm)
                         P_new = P_orig + [0, 0, -0.01]
                                     │
                                     ▼
                            Toggle Boolean State
                             isOn = !isOn
                                     │
                                     ▼
                       Animate Emissive Luminance
                       Intensity: 0.0  ──►  5.0
```

1. **Touch Proximity**:
   Index tip enters button touch volume ($d < d_{threshold}$).

2. **Stroke Motion Animation**:
   Translate button submesh inward along local push axis by stroke depth (e.g., $1.0\text{ cm}$):
   $$\mathbf{P}_{pressed} = \mathbf{P}_{original} + \mathbf{V}_{push} \cdot 0.01\text{m}$$

3. **State Toggle & Emissive Material Ramping**:
   - Toggle state boolean: `component.isOn.toggle()`.
   - Ramp material emissive intensity from baseline ($0.0$) to active ($5.0$) over $0.15\text{s}$ transition duration.

4. **Return Mechanism**:
   - **Momentary Push Button**: Resets position back to $\mathbf{P}_{original}$ as soon as finger exits trigger volume.
   - **Latching Switch Button**: Holds depressed position until pressed a second time.

---

### 7.5 Switch Movement (Rotary Snap & Multi-State Toggle)

```
                       [ Finger Enters Switch Bounds ]
                                     │
                                     ▼
                         Calculate Finger Angle
                           θ_hand = atan2(Y, X)
                                     │
                                     ▼
                       Shortest Angular Difference
                     Δθ = min(|θ_hand - θ_state|, ...)
                                     │
                                     ▼
                     If Δθ < Hysteresis Threshold
                     Snap Rotation to State Angle
```

1. **Switch Angular Solver**:
   Calculate hand angle in switch plane:
   $$\theta_{hand} = \text{atan2}(P_{local, y} - P_{switch, y}, P_{local, x} - P_{switch, x})$$

2. **Shortest Angular Distance Hysteresis**:
   For each discrete switch position state $\theta_{state, i} \in \{\text{OFF}, \text{AUTO}, \text{ON}\}$:
   $$\Delta \theta = \min\left(|\theta_{hand} - \theta_{state, i}|, 2\pi - |\theta_{hand} - \theta_{state, i}|\right)$$
   $$\text{If } \Delta \theta < \theta_{hysteresis} \implies \text{currentStateIndex} = i$$

3. **Snap Rotation Application**:
   $$\mathbf{Q}_{switch} = \text{simd\_quatf}(\text{angle}: \theta_{state, i}, \text{axis}: \mathbf{A}_{localAxis})$$
   $$\text{entity.transform.rotation} = \mathbf{Q}_{switch}$$

---

## 8. Next Steps & Implementation Roadmap

1. **Immediate Parameter Tuning**:
   - Reduce `EmissiveButtonSystem` distance threshold from `0.035m` (3.5 cm) to `0.012m` (1.2 cm).
   - Replace the `+0.05m` expansion box in `LinearActuatorSystem` and `SnappingSwitchSystem` with exact local bounds padding (`+0.005m`).
2. **Transition to Local OBB / Mesh Colliders**:
   - Add `triggerDimensions: SIMD3<Float>` to item component definitions (`EmissiveButtonComponent`, `RotationalKnobComponent`).
   - Implement local space transform testing (`worldToLocal`) across systems to handle panel rotations correctly.
3. **Adopt `CollisionComponent` for Complex Handles**:
   - For `JoystickComponent` and `LeverComponent`, generate convex collision shapes (`ShapeResource.generateConvex(from:)`) to restrict grabs to the physical handle grips.
