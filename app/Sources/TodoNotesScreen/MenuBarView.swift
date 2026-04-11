import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState

    private var statusText: String {
        if let error = appState.lastError {
            return "Error: \(error)"
        }
        if let date = appState.lastUpdated {
            let f = RelativeDateTimeFormatter()
            f.unitsStyle = .abbreviated
            return "Updated \(f.localizedString(for: date, relativeTo: Date()))"
        }
        return "Not yet updated"
    }

    var body: some View {
        Text(statusText)
            .foregroundStyle(.secondary)

        Divider()

        Button(appState.isRefreshing ? "Refreshing…" : "Refresh Now") {
            Task { await appState.refresh() }
        }
        .disabled(appState.isRefreshing)

        if appState.isRunning {
            Button("Pause Auto-Refresh") { appState.stop() }
        } else {
            Button("Resume Auto-Refresh") { appState.start() }
        }

        Divider()

        Button(appState.launchAtLogin ? "✓ Launch at Login" : "Launch at Login") {
            appState.toggleLaunchAtLogin()
        }

        Divider()

        Button("Quit") { NSApplication.shared.terminate(nil) }
    }
}
