import Foundation
import RealityKit

/// Strongly-typed model mapping the exact Reality Composer Pro entity hierarchy for Cockpit27.
public struct CockpitModel {
    
    // MARK: - Hierarchy Entity Names
    public struct EntityNames {
        // Root Containers
        public static let updatedCockpit = "updatedcockpit"
        public static let cockpitA320 = "Cockpit_A320"
        public static let root = "root"
        public static let centralPedestal = "Central_Pedestal"
        
        // Flight Controls
        public static let sidestick = "Sidestick"
        public static let throttleLeft = "CP_Lever_Throttle_L_Rig"
        public static let throttleRight = "CP_Lever_Throttle_R_Rig"
        public static let throttleLegacyFallback = "Throttle 1"
        
        // Engine Controls
        public static let engine1Switch = "CP_Switch_Throttle_ENG1_Rig"
        public static let engine2Switch = "CP_Switch_Throttle_ENG2_Rig"
        public static let engineModeKnob = "CP_Knob_Throttle_EngineMode_Rig"
        
        // Trim Knobs & Wheels
        public static let pitchTrimKnobLeft = "CP_Knob_Throttle_PitchTrimL_Rig"
        public static let pitchTrimKnobRight = "CP_Knob_Throttle_PitchTrimR_Rig"
        public static let pitchTrimWheelLeft = "CP_Knob_Throttle_PitchTrimWheelL_Rig"
        public static let pitchTrimWheelRight = "CP_Knob_Throttle_PitchTrimWheelR_Rig"
        
        // Emissive Fire Fault Buttons
        public static let fireFaultButtonLeft = "CP_Button_Throttle_FireFaultL_Rig"
        public static let fireFaultButtonRight = "CP_Button_Throttle_FireFaultR_Rig"
        
        // Panels & Structural Components
        public static let switchingPanelParent = "CP_SwitchingPanel_Parent"
        public static let mcdulParentLeft = "CP_MCDUL_Parent"
        public static let mcdulParentRight = "CP_MCDUL_Parent (1)"
        public static let ecamParent = "CP_ECAM_Parent"
        public static let base = "CP_Base"
        public static let body = "body"
        public static let windshield = "Cockpit_A320_Windshield"
        
        /// All interactable button & switch entity names on the pedestal
        public static let pedestalInteractableNames: [String] = [
            fireFaultButtonLeft,
            fireFaultButtonRight,
            engine1Switch,
            engine2Switch,
            engineModeKnob,
            pitchTrimKnobLeft,
            pitchTrimKnobRight,
            pitchTrimWheelLeft,
            pitchTrimWheelRight
        ]
    }
    
    // MARK: - Loaded Entity References
    public var rootScene: Entity?
    public var cockpitA320: Entity?
    public var centralPedestal: Entity?
    
    public var sidestick: Entity?
    public var throttleLeft: Entity?
    public var throttleRight: Entity?
    
    public var engine1Switch: Entity?
    public var engine2Switch: Entity?
    public var engineModeKnob: Entity?
    
    public var pitchTrimKnobLeft: Entity?
    public var pitchTrimKnobRight: Entity?
    public var pitchTrimWheelLeft: Entity?
    public var pitchTrimWheelRight: Entity?
    
    public var fireFaultButtonLeft: Entity?
    public var fireFaultButtonRight: Entity?
    
    public var switchingPanelParent: Entity?
    public var mcdulParentLeft: Entity?
    public var mcdulParentRight: Entity?
    public var ecamParent: Entity?
    
    public init() {}
    
    /// Populates entity references from a loaded RealityKit scene entity.
    public mutating func populate(from scene: Entity) {
        self.rootScene = scene
        self.cockpitA320 = scene.findEntity(named: EntityNames.cockpitA320)
        self.centralPedestal = scene.findEntity(named: EntityNames.centralPedestal)
        
        self.sidestick = scene.findEntity(named: EntityNames.sidestick)
        self.throttleLeft = scene.findEntity(named: EntityNames.throttleLeft) ?? scene.findEntity(named: EntityNames.throttleLegacyFallback)
        self.throttleRight = scene.findEntity(named: EntityNames.throttleRight)
        
        self.engine1Switch = scene.findEntity(named: EntityNames.engine1Switch)
        self.engine2Switch = scene.findEntity(named: EntityNames.engine2Switch)
        self.engineModeKnob = scene.findEntity(named: EntityNames.engineModeKnob)
        
        self.pitchTrimKnobLeft = scene.findEntity(named: EntityNames.pitchTrimKnobLeft)
        self.pitchTrimKnobRight = scene.findEntity(named: EntityNames.pitchTrimKnobRight)
        self.pitchTrimWheelLeft = scene.findEntity(named: EntityNames.pitchTrimWheelLeft)
        self.pitchTrimWheelRight = scene.findEntity(named: EntityNames.pitchTrimWheelRight)
        
        self.fireFaultButtonLeft = scene.findEntity(named: EntityNames.fireFaultButtonLeft)
        self.fireFaultButtonRight = scene.findEntity(named: EntityNames.fireFaultButtonRight)
        
        self.switchingPanelParent = scene.findEntity(named: EntityNames.switchingPanelParent)
        self.mcdulParentLeft = scene.findEntity(named: EntityNames.mcdulParentLeft)
        self.mcdulParentRight = scene.findEntity(named: EntityNames.mcdulParentRight)
        self.ecamParent = scene.findEntity(named: EntityNames.ecamParent)
    }
}
