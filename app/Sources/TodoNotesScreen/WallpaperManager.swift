import AppKit

enum WallpaperManager {
    /// Sets the desktop wallpaper on all screens. On macOS Sequoia with default
    /// settings (lock screen linked to desktop), this also updates the lock screen.
    static func set(path: String) {
        guard FileManager.default.fileExists(atPath: path) else { return }
        let url = URL(fileURLWithPath: path)
        for screen in NSScreen.screens {
            try? NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [:])
        }
    }
}
