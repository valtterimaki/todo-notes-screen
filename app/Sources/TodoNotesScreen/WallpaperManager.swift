import AppKit

enum WallpaperManager {
    /// Sets the desktop wallpaper on all screens. On macOS Sequoia with default
    /// settings (lock screen linked to desktop), this also updates the lock screen.
    ///
    /// macOS caches wallpaper images by URL, so we copy to a unique timestamped
    /// path on each call to force a cache miss, then clean up the previous copy.
    static func set(path: String) {
        guard FileManager.default.fileExists(atPath: path) else { return }
        let source = URL(fileURLWithPath: path)
        let dir = source.deletingLastPathComponent()
        let unique = dir.appendingPathComponent("wallpaper_\(Int(Date().timeIntervalSince1970)).png")

        do {
            try FileManager.default.copyItem(at: source, to: unique)
        } catch {
            // Fall back to the original path if copy fails
            for screen in NSScreen.screens {
                try? NSWorkspace.shared.setDesktopImageURL(source, for: screen, options: [:])
            }
            return
        }

        for screen in NSScreen.screens {
            try? NSWorkspace.shared.setDesktopImageURL(unique, for: screen, options: [:])
        }

        // Remove stale cached copies (any wallpaper_*.png that isn't the one we just set)
        let stale = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        for file in stale where file.lastPathComponent.hasPrefix("wallpaper_") && file != unique {
            try? FileManager.default.removeItem(at: file)
        }
    }
}
