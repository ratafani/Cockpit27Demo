import SwiftUI
import Cockpit27UI

@main
struct Cockpit27App: App {
    @State private var coordinator = AppCoordinator()
    
    var body: some Scene {
        WindowGroup {
            RootCoordinatorView(coordinator: coordinator)
        }

        ImmersiveSpace(id: "ImmersiveSpace") {
            ImmersiveSimulationView(showGloves: $coordinator.showGloves, hidePhysicalHand: $coordinator.hidePhysicalHand, onExit: {
                Task {
                    await coordinator.backToIntro()
                }
            })
        }
        .immersionStyle(selection: .constant(.full), in: .full)
    }
}