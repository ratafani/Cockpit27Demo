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
                VStack {
                    Text("Simulation Running")
                        .font(.headline)
                    Button("Exit Simulation") {
                        Task {
                            await coordinator.backToIntro()
                        }
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            coordinator.openImmersiveSpace = openImmersiveSpace
            coordinator.dismissImmersiveSpace = dismissImmersiveSpace
        }
    }
}
