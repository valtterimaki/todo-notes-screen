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

        if let desktoppr = desktopprPath() {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: desktoppr)
            p.arguments = [path]
            try? p.run()
            p.waitUntilExit()
            return
        }

        // Fallback: NSWorkspace (desktop only — lock screen won't update on Sonoma+)
        let source = URL(fileURLWithPath: path)
        let dir = source.deletingLastPathComponent()
        let unique = dir.appendingPathComponent("wallpaper_\(Int(Date().timeIntervalSince1970)).png")

        do {
            try FileManager.default.copyItem(at: source, to: unique)
        } catch {
            for screen in NSScreen.screens {
                try? NSWorkspace.shared.setDesktopImageURL(source, for: screen, options: [:])
            }
            return
        }

        for screen in NSScreen.screens {
            try? NSWorkspace.shared.setDesktopImageURL(unique, for: screen, options: [:])
        }

        let stale = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        for file in stale where file.lastPathComponent.hasPrefix("wallpaper_") && file != unique {
            try? FileManager.default.removeItem(at: file)
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
