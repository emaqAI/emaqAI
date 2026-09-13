import SwiftUI

@main
struct CPUMonitorApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup("Monitor CPU AI") {
            ContentView()
                .environmentObject(state)
        }
    }
}
