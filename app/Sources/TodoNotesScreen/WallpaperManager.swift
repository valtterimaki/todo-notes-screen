import AppKit

enum WallpaperManager {
    /// Sets the desktop and lock screen wallpaper.
    ///
    /// Uses `desktoppr` (brew install desktoppr) when available, because on macOS
    /// Sonoma+ NSWorkspace.setDesktopImageURL only updates the desktop entry in the
    /// wallpaper database — the lock screen entry is separate and only desktoppr
    /// (via private WallpaperKit APIs) writes both at once.
    ///
    /// Falls back to NSWorkspace if desktoppr is not installed (desktop only).
    static func set(path: String) {
        guard FileManager.default.fileExists(atPath: path) else { return }

        // macOS caches wallpapers by URL — copy to a unique timestamped path each time
        // so both desktoppr and NSWorkspace see a "new" URL and reload the image content.
        let source = URL(fileURLWithPath: path)
        let dir = source.deletingLastPathComponent()
        let unique = dir.appendingPathComponent("wallpaper_\(Int(Date().timeIntervalSince1970)).png")

        do {
            try FileManager.default.copyItem(at: source, to: unique)
        } catch {
            // Copy failed — fall back to original path (may not refresh visually)
            applyWallpaper(path: path)
            return
        }

        applyWallpaper(path: unique.path)

        let stale = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        for file in stale where file.lastPathComponent.hasPrefix("wallpaper_") && file != unique {
            try? FileManager.default.removeItem(at: file)
        }
    }

    private static func applyWallpaper(path: String) {
        if let desktoppr = desktopprPath() {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: desktoppr)
            p.arguments = [path]
            try? p.run()
            p.waitUntilExit()
        } else {
            // Fallback: desktop only — lock screen won't update on Sonoma+
            let url = URL(fileURLWithPath: path)
            for screen in NSScreen.screens {
                try? NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [:])
            }
        }
    }

    private static func desktopprPath() -> String? {
        let candidates = [
            "/opt/homebrew/bin/desktoppr",  // Apple Silicon
            "/usr/local/bin/desktoppr",     // Intel
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0) }
    }
}
