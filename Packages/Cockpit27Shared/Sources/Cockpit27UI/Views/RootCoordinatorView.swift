import SwiftUI

public struct RootCoordinatorView: View {
    @Bindable var coordinator: AppCoordinator
    
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    
    public init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }
    
    public var body: some View {
        Group {
            switch coordinator.currentState {
            case .intro:
                IntroView(coordinator: coordinator)
            case .immersive:
                // When immersive, show nothing in the window or a minimal control panel
                VStack(spacing: 20) {
                    Text("Simulation Running")
                        .font(.headline)
                    
                    Toggle("Show Gloves", isOn: $coordinator.showGloves)
                        .padding(.horizontal)
                    
                    Toggle("Hide Physical Hand", isOn: $coordinator.hidePhysicalHand)
                        .padding(.horizontal)
                        
                    Button("Exit Simulation") {
                        Task {
                            await coordinator.backToIntro()
                        }
                    }
                    .padding()
                }
                .padding()
                .glassBackgroundEffect()
            }
        }
        .onAppear {
            coordinator.openImmersiveSpace = openImmersiveSpace
            coordinator.dismissImmersiveSpace = dismissImmersiveSpace
        }
    }
}
