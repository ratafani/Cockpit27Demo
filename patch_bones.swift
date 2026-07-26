import Foundation

let path = "/Volumes/Taftaf Personal/VisionOS Training/Airbus Proj/Cockpit27/Packages/Cockpit27Shared/Sources/Cockpit27Simulation/SpatialInteractionSystem.swift"
var content = try! String(contentsOfFile: path)

// Replace SkeletalPosesComponent block in Gimbal
let oldGimbalBlock = """
                if let pivot = comp.pivotEntity {
                    if let (spcEntity, spc) = getSkeletalPoses(from: pivot), var pose = spc.poses.first, !pose.jointTransforms.isEmpty {
                        let jointIdx = pose.jointTransforms.count - 1 // Apply to the leaf bone
                        if comp.initialBoneRotation == nil {
                            comp.initialBoneRotation = pose.jointTransforms[jointIdx].rotation
                        }
                        let initial = comp.initialBoneRotation!
                        pose.jointTransforms[jointIdx].rotation = combinedQ * initial
                        spcEntity.components.set(SkeletalPosesComponent(poses: [pose]))
                        print("[GIM] Bone \\(jointIdx) rotated via SkeletalPosesComponent")
                    } else {
                        if comp.initialEntityRotation == nil {
                            comp.initialEntityRotation = pivot.transform.rotation
                        }
                        let initial = comp.initialEntityRotation!
                        pivot.transform.rotation = combinedQ * initial
                        print("[GIM] Entity rotated (NO SkeletalPosesComponent found!)")
                    }
                } else {
"""

let newGimbalBlock = """
                if let pivot = comp.pivotEntity {
                    if let model = pivot as? ModelEntity, !model.jointTransforms.isEmpty {
                        let jointIdx = model.jointTransforms.count - 1
                        if comp.initialBoneRotation == nil {
                            comp.initialBoneRotation = model.jointTransforms[jointIdx].rotation
                        }
                        let initial = comp.initialBoneRotation!
                        var transforms = model.jointTransforms
                        transforms[jointIdx].rotation = combinedQ * initial
                        model.jointTransforms = transforms
                        // print("[GIM] Bone \\(jointIdx) rotated via ModelEntity.jointTransforms")
                    } else {
                        if comp.initialEntityRotation == nil {
                            comp.initialEntityRotation = pivot.transform.rotation
                        }
                        let initial = comp.initialEntityRotation!
                        pivot.transform.rotation = combinedQ * initial
                        // print("[GIM] Entity rotated (NO ModelEntity joints found!)")
                    }
                } else {
"""

content = content.replacingOccurrences(of: oldGimbalBlock, with: newGimbalBlock)

// Replace SkeletalPosesComponent block in ArcLever (duplicate the same logic for ArcLever)
let oldArcLeverBlock = """
                if let pivot = comp.pivotEntity {
                    if let (spcEntity, spc) = getSkeletalPoses(from: pivot), var pose = spc.poses.first, !pose.jointTransforms.isEmpty {
                        let jointIdx = pose.jointTransforms.count - 1 // Apply to the leaf bone
                        if comp.initialBoneRotation == nil {
                            comp.initialBoneRotation = pose.jointTransforms[jointIdx].rotation
                        }
                        let initial = comp.initialBoneRotation!
                        pose.jointTransforms[jointIdx].rotation = quat * initial
                        spcEntity.components.set(SkeletalPosesComponent(poses: [pose]))
                        print("[ARC] Bone \\(jointIdx) rotated via SkeletalPosesComponent")
                    } else {
                        if comp.initialEntityRotation == nil {
                            comp.initialEntityRotation = pivot.transform.rotation
                        }
                        let initial = comp.initialEntityRotation!
                        pivot.transform.rotation = quat * initial
                        print("[ARC] Entity rotated (NO SkeletalPosesComponent found!)")
                    }
                } else {
"""

let newArcLeverBlock = """
                if let pivot = comp.pivotEntity {
                    if let model = pivot as? ModelEntity, !model.jointTransforms.isEmpty {
                        let jointIdx = model.jointTransforms.count - 1
                        if comp.initialBoneRotation == nil {
                            comp.initialBoneRotation = model.jointTransforms[jointIdx].rotation
                        }
                        let initial = comp.initialBoneRotation!
                        var transforms = model.jointTransforms
                        transforms[jointIdx].rotation = quat * initial
                        model.jointTransforms = transforms
                    } else {
                        if comp.initialEntityRotation == nil {
                            comp.initialEntityRotation = pivot.transform.rotation
                        }
                        let initial = comp.initialEntityRotation!
                        pivot.transform.rotation = quat * initial
                    }
                } else {
"""

content = content.replacingOccurrences(of: oldArcLeverBlock, with: newArcLeverBlock)

// Fix reset block for ArcLever
let oldArcLeverReset = """
            if let pivot = comp.pivotEntity {
                if let (spcEntity, spc) = getSkeletalPoses(from: pivot), var pose = spc.poses.first, !pose.jointTransforms.isEmpty {
                    let jointIdx = pose.jointTransforms.count - 1
                    if comp.initialBoneRotation == nil {
                        comp.initialBoneRotation = pose.jointTransforms[jointIdx].rotation
                    }
                    let initial = comp.initialBoneRotation!
                    pose.jointTransforms[jointIdx].rotation = combinedQ * initial
                    spcEntity.components.set(SkeletalPosesComponent(poses: [pose]))
                } else {
                    if comp.initialEntityRotation == nil {
                        comp.initialEntityRotation = pivot.transform.rotation
                    }
                    let initial = comp.initialEntityRotation!
                    pivot.transform.rotation = combinedQ * initial
                }
"""

let newArcLeverReset = """
            if let pivot = comp.pivotEntity {
                if let model = pivot as? ModelEntity, !model.jointTransforms.isEmpty {
                    let jointIdx = model.jointTransforms.count - 1
                    if comp.initialBoneRotation == nil {
                        comp.initialBoneRotation = model.jointTransforms[jointIdx].rotation
                    }
                    let initial = comp.initialBoneRotation!
                    var transforms = model.jointTransforms
                    transforms[jointIdx].rotation = combinedQ * initial
                    model.jointTransforms = transforms
                } else {
                    if comp.initialEntityRotation == nil {
                        comp.initialEntityRotation = pivot.transform.rotation
                    }
                    let initial = comp.initialEntityRotation!
                    pivot.transform.rotation = combinedQ * initial
                }
"""
content = content.replacingOccurrences(of: oldArcLeverReset, with: newArcLeverReset)


// Change hand proxy radius
content = content.replacingOccurrences(of: "ShapeResource.generateSphere(radius: 0.05)", with: "ShapeResource.generateSphere(radius: 0.015)")
content = content.replacingOccurrences(of: "ShapeResource.generateSphere(radius: 0.04)", with: "ShapeResource.generateSphere(radius: 0.01)")

try! content.write(toFile: path, atomically: true, encoding: .utf8)
