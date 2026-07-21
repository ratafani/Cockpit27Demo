import SwiftUI

public struct IntroView: View {
    var coordinator: AppCoordinator
    
    public init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to Cockpit27")
                .font(.title)
            
            Button("Launch Immersive Cockpit") {
                Task {
                    await coordinator.launchSimulation()
                }
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .padding()
    }
}
