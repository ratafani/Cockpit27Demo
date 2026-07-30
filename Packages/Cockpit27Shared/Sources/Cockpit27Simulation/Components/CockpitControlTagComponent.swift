import RealityKit

/// Universal metadata component attached to all interactive cockpit items for telemetry, debugging, and state inspection
public struct CockpitControlTagComponent: Component {
    public var controlID: String
    public var category: String // e.g. "FlightControls", "OverheadPanel", "Pedestal"
    public var normalizedValue: Float = 0.0 // 0.0 to 1.0 representation
    public var currentStateIndex: Int? = nil
    public var isHandAttached: Bool = false
    public var isDebugHighlighted: Bool = false
    
    public init(
        controlID: String,
        category: String = "Uncategorized",
        normalizedValue: Float = 0.0,
        currentStateIndex: Int? = nil,
        isHandAttached: Bool = false,
        isDebugHighlighted: Bool = false
    ) {
        self.controlID = controlID
        self.category = category
        self.normalizedValue = normalizedValue
        self.currentStateIndex = currentStateIndex
        self.isHandAttached = isHandAttached
        self.isDebugHighlighted = isDebugHighlighted
    }
}
