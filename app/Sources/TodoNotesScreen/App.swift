import SwiftUI

@main
struct TodoNotesScreenApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            Image(systemName: appState.isRefreshing ? "arrow.clockwise" : "checklist")
        }
        .menuBarExtraStyle(.menu)
    }
}
