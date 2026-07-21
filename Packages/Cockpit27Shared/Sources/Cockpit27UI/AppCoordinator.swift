import Foundation
import SwiftUI

@Observable
public class AppCoordinator {
    public var openImmersiveSpace: OpenImmersiveSpaceAction?
    public var dismissImmersiveSpace: DismissImmersiveSpaceAction?
    
    public enum AppState {
        case intro
        case immersive
    }
    
    public var currentState: AppState = .intro
    
    public init() {}
    
    @MainActor
    public func launchSimulation() async {
        guard currentState != .immersive else { return }
        
        if let open = openImmersiveSpace {
            switch await open(id: "ImmersiveSpace") {
            case .opened:
                currentState = .immersive
            case .error, .userCancelled:
                print("Failed or cancelled opening immersive space")
            @unknown default:
                break
            }
        }
    }
    
    @MainActor
    public func backToIntro() async {
        guard currentState != .intro else { return }
        
        if let dismiss = dismissImmersiveSpace {
            await dismiss()
            currentState = .intro
        }
    }
}
