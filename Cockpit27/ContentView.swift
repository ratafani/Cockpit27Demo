import SwiftUI
import RealityKit
import RealityKitContent

struct ContentView: View {
    var body: some View {
        VStack {
            Text("Welcome to Cockpit27")
            Model3D(named: "Scene", bundle: realityKitContentBundle)
        }
        .padding()
    }
}