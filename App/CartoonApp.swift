import SwiftUI

@main
struct CartoonShortApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                ContentView()
                    .tabItem { Label("Voice & Render", systemImage: "film") }
                ScriptMakerView()
                    .tabItem { Label("Script Maker", systemImage: "pencil.and.outline") }
            }
        }
    }
}
